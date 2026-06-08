package provider

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/bedrockagentcorecontrol"
	"github.com/aws/aws-sdk-go-v2/service/bedrockagentcorecontrol/types"
)

const (
	pollInterval = 5 * time.Second
	pollTimeout  = 10 * time.Minute
)

// idFromARN returns the trailing identifier segment of an ARN
// (e.g. arn:...:registry/abc123 -> abc123). If the value is not an ARN it is
// returned unchanged.
func idFromARN(arn string) string {
	if i := strings.LastIndex(arn, "/"); i >= 0 {
		return arn[i+1:]
	}
	return arn
}

// clientFromProviderData extracts the AgentCore control plane client passed by
// the provider's Configure method.
func clientFromProviderData(providerData any) (*bedrockagentcorecontrol.Client, error) {
	if providerData == nil {
		return nil, nil
	}
	client, ok := providerData.(*bedrockagentcorecontrol.Client)
	if !ok {
		return nil, fmt.Errorf("unexpected provider data type %T, expected *bedrockagentcorecontrol.Client", providerData)
	}
	return client, nil
}

// isNotFound reports whether err is a ResourceNotFoundException.
func isNotFound(err error) bool {
	var nfe *types.ResourceNotFoundException
	return errors.As(err, &nfe)
}

// waitRegistryReady polls GetRegistry until the registry reaches READY or a
// terminal failure state.
func waitRegistryReady(ctx context.Context, client *bedrockagentcorecontrol.Client, registryID string) (*bedrockagentcorecontrol.GetRegistryOutput, error) {
	deadline := time.Now().Add(pollTimeout)
	for {
		out, err := client.GetRegistry(ctx, &bedrockagentcorecontrol.GetRegistryInput{RegistryId: &registryID})
		if err != nil {
			return nil, err
		}
		switch out.Status {
		case types.RegistryStatusReady:
			return out, nil
		case types.RegistryStatusCreateFailed, types.RegistryStatusUpdateFailed, types.RegistryStatusDeleteFailed:
			reason := ""
			if out.StatusReason != nil {
				reason = *out.StatusReason
			}
			return nil, fmt.Errorf("registry %s entered failure state %s: %s", registryID, out.Status, reason)
		}
		if time.Now().After(deadline) {
			return nil, fmt.Errorf("timed out waiting for registry %s to become READY (last status: %s)", registryID, out.Status)
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(pollInterval):
		}
	}
}

// waitRecordSettled polls GetRegistryRecord until the record leaves the
// transient CREATING/UPDATING state.
func waitRecordSettled(ctx context.Context, client *bedrockagentcorecontrol.Client, registryID, recordID string) (*bedrockagentcorecontrol.GetRegistryRecordOutput, error) {
	deadline := time.Now().Add(pollTimeout)
	for {
		out, err := client.GetRegistryRecord(ctx, &bedrockagentcorecontrol.GetRegistryRecordInput{
			RegistryId: &registryID,
			RecordId:   &recordID,
		})
		if err != nil {
			return nil, err
		}
		switch out.Status {
		case types.RegistryRecordStatusCreating, types.RegistryRecordStatusUpdating:
			// keep polling
		case types.RegistryRecordStatusCreateFailed, types.RegistryRecordStatusUpdateFailed:
			reason := ""
			if out.StatusReason != nil {
				reason = *out.StatusReason
			}
			return nil, fmt.Errorf("record %s entered failure state %s: %s", recordID, out.Status, reason)
		default:
			return out, nil
		}
		if time.Now().After(deadline) {
			return nil, fmt.Errorf("timed out waiting for record %s to settle (last status: %s)", recordID, out.Status)
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(pollInterval):
		}
	}
}
