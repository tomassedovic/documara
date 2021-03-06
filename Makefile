PROG = documara
BUILD_DIR = build
ASSETS_DIR = assets/js
OUTPUT_DIR = $(BUILD_DIR)/$(PROG)
CC = node_modules/coffee-script/bin/coffee

build: server static assets
	tar -C $(BUILD_DIR) -czf $(BUILD_DIR)/documara.`git rev-parse HEAD`.tar.gz $(PROG)
	rm -rf $(OUTPUT_DIR)

server: appserver.js api.js dbi.js
	cp package.json $(OUTPUT_DIR)
	cp README.md $(OUTPUT_DIR)
	cp -r static $(OUTPUT_DIR)

assets: $(ASSETS_DIR)/documents.js $(ASSETS_DIR)/lists.js $(ASSETS_DIR)/utils.js

run:
	npm install && PORT=8080 SESSION_SECRET="insecure" NODE_ENV=development $(CC) appserver.coffee

clean:
	rm -rf $(BUILD_DIR)

$(ASSETS_DIR)/%.js: $(ASSETS_DIR)/%.coffee
	$(CC) --output $(OUTPUT_DIR)/static/js --compile $<

%.js: %.coffee
	$(CC) --output $(OUTPUT_DIR) --compile $<

.PHONY: build server assets clean run
