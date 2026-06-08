package provider

import (
	"context"
	"fmt"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/bedrockagentcorecontrol"
	"github.com/aws/aws-sdk-go-v2/service/bedrockagentcorecontrol/types"

	"github.com/hashicorp/terraform-plugin-framework/diag"
	"github.com/hashicorp/terraform-plugin-framework/path"
	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/booldefault"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/objectplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/planmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/stringplanmodifier"
	frameworktypes "github.com/hashicorp/terraform-plugin-framework/types"
)

var (
	_ resource.Resource                = &registryRecordResource{}
	_ resource.ResourceWithConfigure   = &registryRecordResource{}
	_ resource.ResourceWithImportState = &registryRecordResource{}
)

type registryRecordResource struct {
	client *bedrockagentcorecontrol.Client
}

type registryRecordResourceModel struct {
	ID                frameworktypes.String `tfsdk:"id"`
	RegistryID        frameworktypes.String `tfsdk:"registry_id"`
	Name              frameworktypes.String `tfsdk:"name"`
	DescriptorType    frameworktypes.String `tfsdk:"descriptor_type"`
	RecordVersion     frameworktypes.String `tfsdk:"record_version"`
	Description       frameworktypes.String `tfsdk:"description"`
	SubmitForApproval frameworktypes.Bool   `tfsdk:"submit_for_approval"`
	Descriptors       *descriptorsModel     `tfsdk:"descriptors"`
	ARN               frameworktypes.String `tfsdk:"arn"`
	Status            frameworktypes.String `tfsdk:"status"`
}

type descriptorsModel struct {
	A2A         *a2aModel         `tfsdk:"a2a"`
	Mcp         *mcpModel         `tfsdk:"mcp"`
	Custom      *customModel      `tfsdk:"custom"`
	AgentSkills *agentSkillsModel `tfsdk:"agent_skills"`
}

type inlineSchemaModel struct {
	SchemaVersion frameworktypes.String `tfsdk:"schema_version"`
	InlineContent frameworktypes.String `tfsdk:"inline_content"`
}

type a2aModel struct {
	AgentCard *inlineSchemaModel `tfsdk:"agent_card"`
}

type mcpModel struct {
	Server *inlineSchemaModel `tfsdk:"server"`
	Tools  *mcpToolsModel     `tfsdk:"tools"`
}

type mcpToolsModel struct {
	ProtocolVersion frameworktypes.String `tfsdk:"protocol_version"`
	InlineContent   frameworktypes.String `tfsdk:"inline_content"`
}

type customModel struct {
	InlineContent frameworktypes.String `tfsdk:"inline_content"`
}

type agentSkillsModel struct {
	SkillMd         *skillMdModel      `tfsdk:"skill_md"`
	SkillDefinition *inlineSchemaModel `tfsdk:"skill_definition"`
}

type skillMdModel struct {
	InlineContent frameworktypes.String `tfsdk:"inline_content"`
}

// NewRegistryRecordResource constructs the agentcore_registry_record resource.
func NewRegistryRecordResource() resource.Resource {
	return &registryRecordResource{}
}

func (r *registryRecordResource) Metadata(_ context.Context, req resource.MetadataRequest, resp *resource.MetadataResponse) {
	resp.TypeName = req.ProviderTypeName + "_registry_record"
}

func (r *registryRecordResource) Schema(_ context.Context, _ resource.SchemaRequest, resp *resource.SchemaResponse) {
	inlineSchemaAttrs := func(versionName, versionDesc string) map[string]schema.Attribute {
		return map[string]schema.Attribute{
			versionName: schema.StringAttribute{
				Optional:    true,
				Description: versionDesc,
			},
			"inline_content": schema.StringAttribute{
				Required:    true,
				Description: "JSON content as a string. Use jsonencode(...) to embed an object.",
			},
		}
	}

	resp.Schema = schema.Schema{
		Description: "A record in an AWS Agent Registry (agent, MCP server, skill, or custom resource).",
		Attributes: map[string]schema.Attribute{
			"id": schema.StringAttribute{
				Computed:    true,
				Description: "The unique identifier of the record.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.UseStateForUnknown(),
				},
			},
			"registry_id": schema.StringAttribute{
				Required:    true,
				Description: "ID or ARN of the registry that owns the record. Changing this forces a new record.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.RequiresReplace(),
				},
			},
			"name": schema.StringAttribute{
				Required:    true,
				Description: "Name of the record (1-255 chars). Changing this forces a new record.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.RequiresReplace(),
				},
			},
			"descriptor_type": schema.StringAttribute{
				Required:    true,
				Description: "Descriptor type: MCP, A2A, CUSTOM, or AGENT_SKILLS. Changing this forces a new record.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.RequiresReplace(),
				},
			},
			"record_version": schema.StringAttribute{
				Optional:    true,
				Description: "Version identifier for the record (e.g. 1.0.0). Changing this forces a new record.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.RequiresReplace(),
				},
			},
			"description": schema.StringAttribute{
				Optional:    true,
				Description: "Description of the record. Changing this forces a new record.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.RequiresReplace(),
				},
			},
			"submit_for_approval": schema.BoolAttribute{
				Optional:    true,
				Computed:    true,
				Default:     booldefault.StaticBool(false),
				Description: "When true, the record is submitted for approval after creation (auto-approved if the registry allows it).",
			},
			"arn": schema.StringAttribute{
				Computed:    true,
				Description: "ARN of the record.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.UseStateForUnknown(),
				},
			},
			"status": schema.StringAttribute{
				Computed:    true,
				Description: "Current status of the record (e.g. DRAFT, PENDING_APPROVAL, APPROVED).",
			},
			"descriptors": schema.SingleNestedAttribute{
				Required:    true,
				Description: "Descriptor-type-specific configuration. Provide exactly the block matching descriptor_type. Changing this forces a new record.",
				PlanModifiers: []planmodifier.Object{
					objectplanmodifier.RequiresReplace(),
				},
				Attributes: map[string]schema.Attribute{
					"a2a": schema.SingleNestedAttribute{
						Optional:    true,
						Description: "A2A agent descriptor (descriptor_type = A2A).",
						Attributes: map[string]schema.Attribute{
							"agent_card": schema.SingleNestedAttribute{
								Required:   true,
								Attributes: inlineSchemaAttrs("schema_version", "A2A agent card schema version (e.g. 0.3)."),
							},
						},
					},
					"mcp": schema.SingleNestedAttribute{
						Optional:    true,
						Description: "MCP server descriptor (descriptor_type = MCP).",
						Attributes: map[string]schema.Attribute{
							"server": schema.SingleNestedAttribute{
								Required:   true,
								Attributes: inlineSchemaAttrs("schema_version", "MCP server schema version (e.g. 2025-12-11)."),
							},
							"tools": schema.SingleNestedAttribute{
								Optional: true,
								Attributes: map[string]schema.Attribute{
									"protocol_version": schema.StringAttribute{
										Optional:    true,
										Description: "MCP tools protocol version.",
									},
									"inline_content": schema.StringAttribute{
										Required:    true,
										Description: "MCP tools definition JSON as a string.",
									},
								},
							},
						},
					},
					"custom": schema.SingleNestedAttribute{
						Optional:    true,
						Description: "Custom descriptor (descriptor_type = CUSTOM).",
						Attributes: map[string]schema.Attribute{
							"inline_content": schema.StringAttribute{
								Required:    true,
								Description: "Custom JSON content as a string.",
							},
						},
					},
					"agent_skills": schema.SingleNestedAttribute{
						Optional:    true,
						Description: "Agent skills descriptor (descriptor_type = AGENT_SKILLS).",
						Attributes: map[string]schema.Attribute{
							"skill_md": schema.SingleNestedAttribute{
								Optional: true,
								Attributes: map[string]schema.Attribute{
									"inline_content": schema.StringAttribute{
										Required:    true,
										Description: "Markdown describing the skill.",
									},
								},
							},
							"skill_definition": schema.SingleNestedAttribute{
								Optional:   true,
								Attributes: inlineSchemaAttrs("schema_version", "Skill definition schema version."),
							},
						},
					},
				},
			},
		},
	}
}

func (r *registryRecordResource) Configure(_ context.Context, req resource.ConfigureRequest, resp *resource.ConfigureResponse) {
	client, err := clientFromProviderData(req.ProviderData)
	if err != nil {
		resp.Diagnostics.AddError("Unexpected provider data", err.Error())
		return
	}
	r.client = client
}

func (r *registryRecordResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
	var plan registryRecordResourceModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	if resp.Diagnostics.HasError() {
		return
	}

	descriptors, diags := buildDescriptors(plan.DescriptorType.ValueString(), plan.Descriptors)
	resp.Diagnostics.Append(diags...)
	if resp.Diagnostics.HasError() {
		return
	}

	registryID := plan.RegistryID.ValueString()
	in := &bedrockagentcorecontrol.CreateRegistryRecordInput{
		RegistryId:     aws.String(registryID),
		Name:           plan.Name.ValueStringPointer(),
		DescriptorType: types.DescriptorType(plan.DescriptorType.ValueString()),
		Descriptors:    descriptors,
	}
	if !plan.RecordVersion.IsNull() && plan.RecordVersion.ValueString() != "" {
		in.RecordVersion = plan.RecordVersion.ValueStringPointer()
	}
	if !plan.Description.IsNull() && plan.Description.ValueString() != "" {
		in.Description = plan.Description.ValueStringPointer()
	}

	out, err := r.client.CreateRegistryRecord(ctx, in)
	if err != nil {
		resp.Diagnostics.AddError("Error creating registry record", err.Error())
		return
	}

	recordID := idFromARN(aws.ToString(out.RecordArn))
	got, err := waitRecordSettled(ctx, r.client, registryID, recordID)
	if err != nil {
		resp.Diagnostics.AddError("Error waiting for record to settle", err.Error())
		return
	}

	if plan.SubmitForApproval.ValueBool() {
		sub, err := r.client.SubmitRegistryRecordForApproval(ctx, &bedrockagentcorecontrol.SubmitRegistryRecordForApprovalInput{
			RegistryId: aws.String(registryID),
			RecordId:   aws.String(recordID),
		})
		if err != nil {
			resp.Diagnostics.AddError("Error submitting record for approval", err.Error())
			return
		}
		plan.Status = frameworktypes.StringValue(string(sub.Status))
	} else {
		plan.Status = frameworktypes.StringValue(string(got.Status))
	}

	plan.ID = frameworktypes.StringValue(recordID)
	plan.ARN = frameworktypes.StringValue(aws.ToString(got.RecordArn))
	resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
}

func (r *registryRecordResource) Read(ctx context.Context, req resource.ReadRequest, resp *resource.ReadResponse) {
	var state registryRecordResourceModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}

	out, err := r.client.GetRegistryRecord(ctx, &bedrockagentcorecontrol.GetRegistryRecordInput{
		RegistryId: state.RegistryID.ValueStringPointer(),
		RecordId:   state.ID.ValueStringPointer(),
	})
	if err != nil {
		if isNotFound(err) {
			resp.State.RemoveResource(ctx)
			return
		}
		resp.Diagnostics.AddError("Error reading registry record", err.Error())
		return
	}

	// Only refresh computed/server-owned fields. Configuration fields
	// (descriptors, name, etc.) are kept as stored to avoid diffs from
	// server-side normalization of inline JSON content.
	state.ARN = frameworktypes.StringValue(aws.ToString(out.RecordArn))
	state.Status = frameworktypes.StringValue(string(out.Status))
	state.Name = frameworktypes.StringValue(aws.ToString(out.Name))
	state.DescriptorType = frameworktypes.StringValue(string(out.DescriptorType))
	if out.RecordVersion != nil {
		state.RecordVersion = frameworktypes.StringValue(*out.RecordVersion)
	}

	resp.Diagnostics.Append(resp.State.Set(ctx, &state)...)
}

func (r *registryRecordResource) Update(ctx context.Context, req resource.UpdateRequest, resp *resource.UpdateResponse) {
	var plan, state registryRecordResourceModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}

	registryID := state.RegistryID.ValueString()
	recordID := state.ID.ValueString()

	// The only in-place change supported is toggling submit_for_approval to
	// true; all other attributes force replacement.
	if plan.SubmitForApproval.ValueBool() && !state.SubmitForApproval.ValueBool() {
		sub, err := r.client.SubmitRegistryRecordForApproval(ctx, &bedrockagentcorecontrol.SubmitRegistryRecordForApprovalInput{
			RegistryId: aws.String(registryID),
			RecordId:   aws.String(recordID),
		})
		if err != nil {
			resp.Diagnostics.AddError("Error submitting record for approval", err.Error())
			return
		}
		plan.Status = frameworktypes.StringValue(string(sub.Status))
	} else {
		plan.Status = state.Status
	}

	plan.ID = state.ID
	plan.ARN = state.ARN
	resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
}

func (r *registryRecordResource) Delete(ctx context.Context, req resource.DeleteRequest, resp *resource.DeleteResponse) {
	var state registryRecordResourceModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}

	_, err := r.client.DeleteRegistryRecord(ctx, &bedrockagentcorecontrol.DeleteRegistryRecordInput{
		RegistryId: state.RegistryID.ValueStringPointer(),
		RecordId:   state.ID.ValueStringPointer(),
	})
	if err != nil && !isNotFound(err) {
		resp.Diagnostics.AddError("Error deleting registry record", err.Error())
		return
	}
}

func (r *registryRecordResource) ImportState(ctx context.Context, req resource.ImportStateRequest, resp *resource.ImportStateResponse) {
	parts := strings.SplitN(req.ID, ",", 2)
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		resp.Diagnostics.AddError(
			"Invalid import ID",
			"Expected import ID in the format \"<registry_id>,<record_id>\".",
		)
		return
	}
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("registry_id"), parts[0])...)
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("id"), parts[1])...)
}

// buildDescriptors converts the typed descriptors model into the SDK type,
// validating that the supplied block matches descriptor_type.
func buildDescriptors(descriptorType string, m *descriptorsModel) (*types.Descriptors, diag.Diagnostics) {
	var diags diag.Diagnostics
	if m == nil {
		diags.AddError("Missing descriptors", "descriptors block is required.")
		return nil, diags
	}

	out := &types.Descriptors{}
	switch descriptorType {
	case "A2A":
		if m.A2A == nil || m.A2A.AgentCard == nil {
			diags.AddError("Invalid descriptors", "descriptor_type A2A requires descriptors.a2a.agent_card.")
			return nil, diags
		}
		out.A2a = &types.A2aDescriptor{
			AgentCard: &types.AgentCardDefinition{
				InlineContent: m.A2A.AgentCard.InlineContent.ValueStringPointer(),
				SchemaVersion: optionalString(m.A2A.AgentCard.SchemaVersion),
			},
		}
	case "MCP":
		if m.Mcp == nil || m.Mcp.Server == nil {
			diags.AddError("Invalid descriptors", "descriptor_type MCP requires descriptors.mcp.server.")
			return nil, diags
		}
		mcp := &types.McpDescriptor{
			Server: &types.ServerDefinition{
				InlineContent: m.Mcp.Server.InlineContent.ValueStringPointer(),
				SchemaVersion: optionalString(m.Mcp.Server.SchemaVersion),
			},
		}
		if m.Mcp.Tools != nil {
			mcp.Tools = &types.ToolsDefinition{
				InlineContent:   m.Mcp.Tools.InlineContent.ValueStringPointer(),
				ProtocolVersion: optionalString(m.Mcp.Tools.ProtocolVersion),
			}
		}
		out.Mcp = mcp
	case "CUSTOM":
		if m.Custom == nil {
			diags.AddError("Invalid descriptors", "descriptor_type CUSTOM requires descriptors.custom.")
			return nil, diags
		}
		out.Custom = &types.CustomDescriptor{
			InlineContent: m.Custom.InlineContent.ValueStringPointer(),
		}
	case "AGENT_SKILLS":
		if m.AgentSkills == nil {
			diags.AddError("Invalid descriptors", "descriptor_type AGENT_SKILLS requires descriptors.agent_skills.")
			return nil, diags
		}
		as := &types.AgentSkillsDescriptor{}
		if m.AgentSkills.SkillMd != nil {
			as.SkillMd = &types.SkillMdDefinition{
				InlineContent: m.AgentSkills.SkillMd.InlineContent.ValueStringPointer(),
			}
		}
		if m.AgentSkills.SkillDefinition != nil {
			as.SkillDefinition = &types.SkillDefinition{
				InlineContent: m.AgentSkills.SkillDefinition.InlineContent.ValueStringPointer(),
				SchemaVersion: optionalString(m.AgentSkills.SkillDefinition.SchemaVersion),
			}
		}
		out.AgentSkills = as
	default:
		diags.AddError("Invalid descriptor_type", fmt.Sprintf("Unsupported descriptor_type %q. Use MCP, A2A, CUSTOM, or AGENT_SKILLS.", descriptorType))
		return nil, diags
	}

	return out, diags
}

func optionalString(s frameworktypes.String) *string {
	if s.IsNull() || s.ValueString() == "" {
		return nil
	}
	return s.ValueStringPointer()
}
