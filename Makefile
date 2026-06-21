PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
SCRIPT = src/git-persona
TARGET = $(BINDIR)/git-persona

.PHONY: install update uninstall test clean

install: $(BINDIR)
	@echo "Installing git-persona to $(TARGET)..."
	@cp $(SCRIPT) $(TARGET)
	@chmod +x $(TARGET)
	@echo "Done. Make sure $(BINDIR) is in your PATH."
	@command -v git-persona >/dev/null 2>&1 && echo "Verified: $$(git-persona version)" || echo "Note: $(BINDIR) is not in your PATH. Add it with: export PATH=\"$(BINDIR):$$PATH\""

update: $(BINDIR)
	@echo "Updating git-persona at $(TARGET)..."
	@cp $(SCRIPT) $(TARGET)
	@chmod +x $(TARGET)
	@echo "Done. Updated to: $$(git-persona version)"

uninstall:
	@echo "Uninstalling git-persona from $(TARGET)..."
	@rm -f $(TARGET)
	@echo "Done. Profile data in ~/.config/git-persona was not removed."
	@echo "To remove all profile data manually: rm -rf ~/.config/git-persona"

$(BINDIR):
	@mkdir -p $(BINDIR)

test:
	@echo "Running syntax check..."
	@bash -n $(SCRIPT) && echo "Syntax OK"
	@echo "Running version check..."
	@bash $(SCRIPT) version
	@echo "Running help check..."
	@bash $(SCRIPT) help

clean:
	@echo "Nothing to clean."
