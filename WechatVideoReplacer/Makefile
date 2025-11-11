# Makefile for WechatVideoReplacer
# 模仿 SantanderEscaped 的构建流程

TARGET_CODESIGN = $(shell which ldid)
PROJECT_DIR = $(shell pwd)
BUILD_DIR = $(PROJECT_DIR)/build
ARCHIVE_PATH = $(BUILD_DIR)/WechatVideoReplacer.xcarchive
APP_PATH = $(ARCHIVE_PATH)/Products/Applications/WechatVideoReplacer.app
ROOTHELPER_SRC = $(PROJECT_DIR)/RootHelper/roothelper
PAYLOAD_DIR = $(BUILD_DIR)/Payload
IPA_NAME = WechatVideoReplacer.ipa

.PHONY: all clean archive sign package

all: clean archive sign package

clean:
	@echo "=== Cleaning previous builds ==="
	rm -rf $(BUILD_DIR)
	xcodebuild clean \
		-project WechatVideoReplacer.xcodeproj \
		-scheme WechatVideoReplacer \
		-configuration Release

archive:
	@echo "=== Building and archiving ==="
	xcodebuild archive \
		-project WechatVideoReplacer.xcodeproj \
		-scheme WechatVideoReplacer \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

sign:
	@echo "=== Signing with ldid (Filza method, safe entitlements) ==="
	@if [ ! -f "$(TARGET_CODESIGN)" ]; then \
		echo "❌ ERROR: ldid not found! Install with: brew install ldid"; \
		exit 1; \
	fi
	
	@echo "📝 Step 1: Signing main app with ldid..."
	$(TARGET_CODESIGN) -SWechatVideoReplacer/entitlements.plist $(APP_PATH)/WechatVideoReplacer
	@echo "✅ Main app signed with ldid"
	
	@echo ""
	@echo "📝 Step 2: Verifying embedded entitlements..."
	@$(TARGET_CODESIGN) -e $(APP_PATH)/WechatVideoReplacer | grep -E "container-manager|MobileContainerManager|no-sandbox" | head -6
	
	@echo ""
	@echo "📝 Step 3: Verifying NO banned entitlements..."
	@if $(TARGET_CODESIGN) -e $(APP_PATH)/WechatVideoReplacer | grep -q "cs.debugger\|skip-library-validation"; then \
		echo "❌ ERROR: Banned entitlements found!"; \
		exit 1; \
	else \
		echo "✅ No banned entitlements (cs.debugger, skip-library-validation)"; \
	fi
	
	
	@echo ""
	@echo "✅ Signed with ldid (direct access method)"
	@echo "   - Main app: Signed with container-manager entitlements"
	@echo "   - No banned entitlements"
	@echo "   - No RootHelper needed (using direct access)"

package:
	@echo "=== Creating IPA ==="
	rm -rf $(PAYLOAD_DIR)
	mkdir -p $(PAYLOAD_DIR)
	cp -r $(APP_PATH) $(PAYLOAD_DIR)/
	
	@echo "📝 Adding iTunesMetadata.plist..."
	@if [ -f iTunesMetadata.plist ]; then \
		cp iTunesMetadata.plist $(BUILD_DIR)/; \
		echo "✅ iTunesMetadata.plist added"; \
	fi
	
	@echo "📦 Packaging IPA..."
	cd $(BUILD_DIR) && zip -qr $(IPA_NAME) Payload
	
	@echo ""
	@echo "✅ IPA created successfully!"
	@echo "📁 Location: $(BUILD_DIR)/$(IPA_NAME)"
	@echo "📊 Size: $$(du -h $(BUILD_DIR)/$(IPA_NAME) | cut -f1)"
	@ls -lh $(BUILD_DIR)/$(IPA_NAME)

install-local:
	@echo "=== Installing to local test location ==="
	rm -rf /tmp/WechatVideoReplacer.app
	cp -r $(APP_PATH) /tmp/
	@echo "✅ Installed to: /tmp/WechatVideoReplacer.app"
	@echo "Test with: /tmp/WechatVideoReplacer.app/roothelper test"

test-roothelper:
	@echo "=== Testing roothelper binary ==="
	@if [ -f $(APP_PATH)/roothelper ]; then \
		echo "✓ roothelper exists"; \
		file $(APP_PATH)/roothelper; \
		ls -l $(APP_PATH)/roothelper; \
		ldid -e $(APP_PATH)/roothelper | head -20; \
	else \
		echo "✗ roothelper not found!"; \
		exit 1; \
	fi

help:
	@echo "WechatVideoReplacer Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all              - Clean, build, sign, and package (default)"
	@echo "  clean            - Remove build artifacts"
	@echo "  archive          - Build and archive the app"
	@echo "  sign             - Sign roothelper and set setuid bit"
	@echo "  package          - Create IPA file"
	@echo "  test-roothelper  - Test roothelper binary"
	@echo "  install-local    - Install to /tmp for testing"
	@echo "  help             - Show this help message"
