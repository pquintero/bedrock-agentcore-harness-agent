package provider

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/bedrockagentcorecontrol"
	"github.com/aws/aws-sdk-go-v2/service/bedrockagentcorecontrol/types"

	"github.com/hashicorp/terraform-plugin-framework/path"
	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/booldefault"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/planmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/stringdefault"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/stringplanmodifier"
	frameworktypes "github.com/hashicorp/terraform-plugin-framework/types"
)

var (
	_ resource.Resource                = &registryResource{}
	_ resource.ResourceWithConfigure   = &registryResource{}
	_ resource.ResourceWithImportState = &registryResource{}
)

type registryResource struct {
	client *bedrockagentcorecontrol.Client
}

type registryResourceModel struct {
	ID             frameworktypes.String `tfsdk:"id"`
	Name           frameworktypes.String `tfsdk:"name"`
	Description    frameworktypes.String `tfsdk:"description"`
	AuthorizerType frameworktypes.String `tfsdk:"authorizer_type"`
	AutoApproval   frameworktypes.Bool   `tfsdk:"auto_approval"`
	ARN            frameworktypes.String `tfsdk:"arn"`
	Status         frameworktypes.String `tfsdk:"status"`
}

// NewRegistryResource constructs the agentcore_registry resource.
func NewRegistryResource() resource.Resource {
	return &registryResource{}
}

func (r *registryResource) Metadata(_ context.Context, req resource.MetadataRequest, resp *resource.MetadataResponse) {
	resp.TypeName = req.ProviderTypeName + "_registry"
}

func (r *registryResource) Schema(_ context.Context, _ resource.SchemaRequest, resp *resource.SchemaResponse) {
	resp.Schema = schema.Schema{
		Description: "An AWS Agent Registry: a centralized catalog for agents, MCP servers, skills, and custom resources.",
		Attributes: map[string]schema.Attribute{
			"id": schema.StringAttribute{
				Computed:    true,
				Description: "The unique identifier of the registry.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.UseStateForUnknown(),
				},
			},
			"name": schema.StringAttribute{
				Required:    true,
				Description: "Name of the registry. Must be unique within the account (1-64 chars, alphanumeric and _-./).",
			},
			"description": schema.StringAttribute{
				Optional:    true,
				Description: "Description of the registry.",
			},
			"authorizer_type": schema.StringAttribute{
				Optional:    true,
				Computed:    true,
				Default:     stringdefault.StaticString("AWS_IAM"),
				Description: "Inbound authorization for the registry's search/invoke APIs: AWS_IAM or CUSTOM_JWT. Changing this forces a new registry.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.RequiresReplace(),
				},
			},
			"auto_approval": schema.BoolAttribute{
				Optional:    true,
				Computed:    true,
				Default:     booldefault.StaticBool(false),
				Description: "When true, submitted records are auto-approved and become discoverable; otherwise they require curator approval.",
			},
			"arn": schema.StringAttribute{
				Computed:    true,
				Description: "ARN of the registry.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.UseStateForUnknown(),
				},
			},
			"status": schema.StringAttribute{
				Computed:    true,
				Description: "Current status of the registry.",
			},
		},
	}
}

func (r *registryResource) Configure(_ context.Context, req resource.ConfigureRequest, resp *resource.ConfigureResponse) {
	client, err := clientFromProviderData(req.ProviderData)
	if err != nil {
		resp.Diagnostics.AddError("Unexpected provider data", err.Error())
		return
	}
	r.client = client
}

func (r *registryResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
	var plan registryResourceModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	if resp.Diagnostics.HasError() {
		return
	}

	in := &bedrockagentcorecontrol.CreateRegistryInput{
		Name:           plan.Name.ValueStringPointer(),
		AuthorizerType: types.RegistryAuthorizerType(plan.AuthorizerType.ValueString()),
		ApprovalConfiguration: &types.ApprovalConfiguration{
			AutoApproval: plan.AutoApproval.ValueBool(),
		},
	}
	if !plan.Description.IsNull() && plan.Description.ValueString() != "" {
		in.Description = plan.Description.ValueStringPointer()
	}

	out, err := r.client.CreateRegistry(ctx, in)
	if err != nil {
		resp.Diagnostics.AddError("Error creating registry", err.Error())
		return
	}

	registryID := idFromARN(aws.ToString(out.RegistryArn))
	got, err := waitRegistryReady(ctx, r.client, registryID)
	if err != nil {
		resp.Diagnostics.AddError("Error waiting for registry to become READY", err.Error())
		return
	}

	r.populateModel(&plan, registryID, got)
	resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
}

func (r *registryResource) Read(ctx context.Context, req resource.ReadRequest, resp *resource.ReadResponse) {
	var state registryResourceModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}

	out, err := r.client.GetRegistry(ctx, &bedrockagentcorecontrol.GetRegistryInput{
		RegistryId: state.ID.ValueStringPointer(),
	})
	if err != nil {
		if isNotFound(err) {
			resp.State.RemoveResource(ctx)
			return
		}
		resp.Diagnostics.AddError("Error reading registry", err.Error())
		return
	}

	state.Name = frameworktypes.StringValue(aws.ToString(out.Name))
	state.ARN = frameworktypes.StringValue(aws.ToString(out.RegistryArn))
	state.Status = frameworktypes.StringValue(string(out.Status))
	state.AuthorizerType = frameworktypes.StringValue(string(out.AuthorizerType))
	if out.Description != nil {
		state.Description = frameworktypes.StringValue(*out.Description)
	}
	if out.ApprovalConfiguration != nil {
		state.AutoApproval = frameworktypes.BoolValue(out.ApprovalConfiguration.AutoApproval)
	}

	resp.Diagnostics.Append(resp.State.Set(ctx, &state)...)
}

func (r *registryResource) Update(ctx context.Context, req resource.UpdateRequest, resp *resource.UpdateResponse) {
	var plan, state registryResourceModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}

	registryID := state.ID.ValueString()
	in := &bedrockagentcorecontrol.UpdateRegistryInput{
		RegistryId: aws.String(registryID),
		Name:       plan.Name.ValueStringPointer(),
		ApprovalConfiguration: &types.UpdatedApprovalConfiguration{
			OptionalValue: &types.ApprovalConfiguration{
				AutoApproval: plan.AutoApproval.ValueBool(),
			},
		},
	}
	if !plan.Description.IsNull() && plan.Description.ValueString() != "" {
		in.Description = &types.UpdatedDescription{OptionalValue: plan.Description.ValueStringPointer()}
	} else {
		in.Description = &types.UpdatedDescription{}
	}

	if _, err := r.client.UpdateRegistry(ctx, in); err != nil {
		resp.Diagnostics.AddError("Error updating registry", err.Error())
		return
	}

	got, err := waitRegistryReady(ctx, r.client, registryID)
	if err != nil {
		resp.Diagnostics.AddError("Error waiting for registry update", err.Error())
		return
	}

	r.populateModel(&plan, registryID, got)
	resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
}

func (r *registryResource) Delete(ctx context.Context, req resource.DeleteRequest, resp *resource.DeleteResponse) {
	var state registryResourceModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}

	_, err := r.client.DeleteRegistry(ctx, &bedrockagentcorecontrol.DeleteRegistryInput{
		RegistryId: state.ID.ValueStringPointer(),
	})
	if err != nil && !isNotFound(err) {
		resp.Diagnostics.AddError("Error deleting registry", err.Error())
		return
	}
}

func (r *registryResource) ImportState(ctx context.Context, req resource.ImportStateRequest, resp *resource.ImportStateResponse) {
	resource.ImportStatePassthroughID(ctx, path.Root("id"), req, resp)
}

func (r *registryResource) populateModel(m *registryResourceModel, registryID string, out *bedrockagentcorecontrol.GetRegistryOutput) {
	m.ID = frameworktypes.StringValue(registryID)
	m.Name = frameworktypes.StringValue(aws.ToString(out.Name))
	m.ARN = frameworktypes.StringValue(aws.ToString(out.RegistryArn))
	m.Status = frameworktypes.StringValue(string(out.Status))
	m.AuthorizerType = frameworktypes.StringValue(string(out.AuthorizerType))
	if out.Description != nil {
		m.Description = frameworktypes.StringValue(*out.Description)
	}
	if out.ApprovalConfiguration != nil {
		m.AutoApproval = frameworktypes.BoolValue(out.ApprovalConfiguration.AutoApproval)
	}
}
