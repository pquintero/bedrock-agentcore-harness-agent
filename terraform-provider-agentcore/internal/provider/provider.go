package provider

import (
	"context"

	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrockagentcorecontrol"

	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/provider"
	"github.com/hashicorp/terraform-plugin-framework/provider/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/types"
)

// Ensure the implementation satisfies the provider.Provider interface.
var _ provider.Provider = &agentcoreProvider{}

type agentcoreProvider struct {
	version string
}

type providerModel struct {
	Region  types.String `tfsdk:"region"`
	Profile types.String `tfsdk:"profile"`
}

// New returns a function that constructs the provider, as required by
// providerserver.Serve.
func New(version string) func() provider.Provider {
	return func() provider.Provider {
		return &agentcoreProvider{version: version}
	}
}

func (p *agentcoreProvider) Metadata(_ context.Context, _ provider.MetadataRequest, resp *provider.MetadataResponse) {
	resp.TypeName = "agentcore"
	resp.Version = p.version
}

func (p *agentcoreProvider) Schema(_ context.Context, _ provider.SchemaRequest, resp *provider.SchemaResponse) {
	resp.Schema = schema.Schema{
		Description: "Manage Amazon Bedrock AgentCore Agent Registry resources (preview).",
		Attributes: map[string]schema.Attribute{
			"region": schema.StringAttribute{
				Optional:    true,
				Description: "AWS region to use. Falls back to the standard AWS SDK resolution (AWS_REGION, shared config) when omitted.",
			},
			"profile": schema.StringAttribute{
				Optional:    true,
				Description: "AWS shared config profile to use. Falls back to the default credential chain when omitted.",
			},
		},
	}
}

func (p *agentcoreProvider) Configure(ctx context.Context, req provider.ConfigureRequest, resp *provider.ConfigureResponse) {
	var cfg providerModel
	resp.Diagnostics.Append(req.Config.Get(ctx, &cfg)...)
	if resp.Diagnostics.HasError() {
		return
	}

	var optFns []func(*awsconfig.LoadOptions) error
	if !cfg.Region.IsNull() && cfg.Region.ValueString() != "" {
		optFns = append(optFns, awsconfig.WithRegion(cfg.Region.ValueString()))
	}
	if !cfg.Profile.IsNull() && cfg.Profile.ValueString() != "" {
		optFns = append(optFns, awsconfig.WithSharedConfigProfile(cfg.Profile.ValueString()))
	}

	awsCfg, err := awsconfig.LoadDefaultConfig(ctx, optFns...)
	if err != nil {
		resp.Diagnostics.AddError("Unable to load AWS configuration", err.Error())
		return
	}

	client := bedrockagentcorecontrol.NewFromConfig(awsCfg)
	resp.ResourceData = client
	resp.DataSourceData = client
}

func (p *agentcoreProvider) Resources(_ context.Context) []func() resource.Resource {
	return []func() resource.Resource{
		NewRegistryResource,
		NewRegistryRecordResource,
	}
}

func (p *agentcoreProvider) DataSources(_ context.Context) []func() datasource.DataSource {
	return nil
}
