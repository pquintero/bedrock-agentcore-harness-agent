BINARY := terraform-provider-agentcore
VERSION ?= 0.1.0
OS_ARCH := $(shell go env GOOS)_$(shell go env GOARCH)
MIRROR_DIR := $(HOME)/.terraform.d/plugins/registry.terraform.io/pquintero/agentcore/$(VERSION)/$(OS_ARCH)

.PHONY: build install install-mirror fmt vet test tidy clean

# Build the provider binary into the current directory.
build:
	go build -ldflags "-X main.version=$(VERSION)" -o $(BINARY) .

# Install the provider into $GOBIN (or $GOPATH/bin) for use with dev_overrides.
install:
	go install -ldflags "-X main.version=$(VERSION)" .

# Install into the local filesystem mirror so `terraform init` resolves the
# provider normally (recommended when configs also use local modules and the
# AWS provider). After this, run `terraform init` in the examples as usual.
install-mirror:
	mkdir -p "$(MIRROR_DIR)"
	go build -ldflags "-X main.version=$(VERSION)" -o "$(MIRROR_DIR)/$(BINARY)_v$(VERSION)" .
	@echo "Installed $(BINARY) v$(VERSION) to $(MIRROR_DIR)"

fmt:
	gofmt -s -w .

vet:
	go vet ./...

test:
	go test ./... -count=1

tidy:
	go mod tidy

clean:
	rm -f $(BINARY)
