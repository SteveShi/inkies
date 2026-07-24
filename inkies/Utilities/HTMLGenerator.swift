import Foundation

// MARK: - HTML Generator Helpers

// Helper to load bundled InkJS library only.
func getInkScript() -> String {
    if let path = Bundle.main.path(forResource: "ink.min", ofType: "js", inDirectory: "Scripts") {
        if let content = try? String(contentsOfFile: path, encoding: .utf8) {
            return "<script>\(content)</script>"
        } else {
            return "<script>console.error('local ink.min.js found but failed to read');</script>"
        }
    }
    return "<script>console.error('local ink.min.js NOT found in bundle');</script>"
}

func generateHTML(for inkContext: String, theme: AppTheme) -> String {
    // 安全转义字符串，避免换行符、引号或 HTML 特殊字符破坏 JS 语法
    let safeContentData = (try? JSONSerialization.data(withJSONObject: [inkContext])) ?? Data()
    let safeContentArrayStr = String(data: safeContentData, encoding: .utf8) ?? "[\"\"]"

    let inkScriptTag = getInkScript()

    let textColor = theme == .dark ? "#ccc" : "#333"
    let bgColor = theme == .dark ? "#1e1e1e" : "#fdfdfd"
    let linkColor = theme == .dark ? "#64b5f6" : "#007aff"

    return """
        <!doctype html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Ink Preview</title>
            \(inkScriptTag)
            <style>
            body { 
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; 
                padding: 0;
                margin: 0;
                line-height: 1.65; 
                color: \(textColor);
                background-color: \(bgColor);
                -webkit-font-smoothing: antialiased;
            }
            
            #outer-container {
                padding: 60px 20px;
                max-width: 700px;
                margin: 0 auto;
            }
            
            #story { 
                margin-bottom: 150px; 
            }
            
            h1 { font-size: 2.2em; margin-top: 0; text-align: center; }
            
            p { 
                margin-bottom: 1.4em; 
                animation: fadein 0.4s ease-out;
                opacity: 1;
            }
            
            @keyframes fadein {
                from { opacity: 0; transform: translateY(5px); }
                to { opacity: 1; transform: translateY(0); }
            }
            
            .choice { 
                display: block;
                width: fit-content;
                margin: 15px auto;
                padding: 10px 20px;
                background: rgba(0, 122, 255, 0.05);
                border: 1px solid rgba(0, 122, 255, 0.2);
                border-radius: 20px;
                color: \(linkColor);
                text-decoration: none;
                text-align: center;
                cursor: pointer;
                transition: all 0.2s ease;
                font-size: 0.95em;
            }
            
            .choice:hover {
                background: rgba(0, 122, 255, 0.15);
                border-color: \(linkColor);
                transform: scale(1.02);
            }
            
            .tag {
                display: inline-block;
                color: #999;
                font-size: 0.8em;
                font-family: monospace;
                margin-left: 10px;
                opacity: 0.6;
                vertical-align: middle;
            }
            
            img {
                max-width: 100%;
                border-radius: 8px;
                margin: 20px 0;
                display: block;
            }
            
            .end-marker {
                text-align: center;
                color: #bbb;
                margin-top: 80px;
                font-style: italic;
                letter-spacing: 0.2em;
                font-variant: small-caps;
            }
            
            body.dark .tag { color: #666; }
            body.dark .choice { background: rgba(100, 181, 246, 0.1); border-color: rgba(100, 181, 246, 0.3); }
            
            /* Official Inky Custom Helper Classes */
            .italic { font-style: italic; }
            .bold { font-weight: bold; }
            .centered { text-align: center; }
            .right { text-align: right; }
            .large { font-size: 1.3em; }
            .small { font-size: 0.85em; }
            .hide { display: none; }
        </style>
    </head>
    <body class="\(theme == .dark ? "dark" : "light")">
        <div id="outer-container">
            <div id="story"></div>
        </div>

        <script>
            (function() {
                var storyContent = (\(safeContentArrayStr))[0];
                var story = null;
                var storyContainer = document.getElementById('story');
                
                // History management for re-rendering
                var storyLog = []; // [{text: "", tags: []}]
                var choiceHistory = []; // [choiceIndex]
                
                function log(msg) { console.log("INKIES: " + msg); }

                function clearStory() {
                    storyContainer.innerHTML = '';
                }

                function renderElement(obj) {
                    var trimmedText = obj.text.trim();
                    if (trimmedText.length === 0 && obj.tags.length === 0) return;

                    // Handle Official # CLEAR Tag
                    obj.tags.forEach(function(rawTag) {
                        var tag = rawTag.trim();
                        if (tag.toUpperCase() === "CLEAR") {
                            clearStory();
                        }
                    });

                    // Handle Official # TITLE: tag
                    var titleTag = obj.tags.find(t => t.trim().toUpperCase().startsWith("TITLE:"));
                    if (titleTag) {
                        var h1 = document.createElement('h1');
                        h1.innerText = titleTag.trim().substring(6).trim();
                        storyContainer.appendChild(h1);
                    }
                    
                    if (trimmedText.length > 0) {
                        var p = document.createElement('p');
                        
                        // Parse Official Tags: CLASS, IMAGE
                        obj.tags.forEach(function(rawTag) {
                            var tag = rawTag.trim();
                            var upper = tag.toUpperCase();
                            if (upper.startsWith("CLASS:")) {
                                var classes = tag.substring(6).trim().split(/\\s+/);
                                classes.forEach(c => p.classList.add(c.toLowerCase()));
                            } else if (upper.startsWith("IMAGE:")) {
                                var img = document.createElement('img');
                                img.src = tag.substring(6).trim();
                                storyContainer.appendChild(img);
                            }
                        });

                        p.innerHTML = obj.text;
                        storyContainer.appendChild(p);
                    }
                }

                function renderChoices(choices) {
                    choices.forEach(function(choice) {
                        var a = document.createElement('a');
                        a.classList.add('choice');
                        a.innerHTML = choice.text;
                        a.onclick = function() {
                            makeChoice(choice.index);
                        };
                        storyContainer.appendChild(a);
                    });
                }

                function makeChoice(index) {
                    choiceHistory.push(index);
                    story.ChooseChoiceIndex(index);
                    continueStory();
                }

                function continueStory() {
                    while(story.canContinue) {
                        var text = story.Continue();
                        var tags = story.currentTags;
                        var entry = { text: text, tags: tags };
                        storyLog.push(entry);
                        renderElement(entry);
                    }
                    
                    // Remove old choices
                    var oldChoices = storyContainer.querySelectorAll('.choice');
                    oldChoices.forEach(c => c.remove());
                    
                    if (story.currentChoices.length > 0) {
                        renderChoices(story.currentChoices);
                    } else {
                        var end = document.createElement('div');
                        end.classList.add('end-marker');
                        end.innerHTML = "&mdash; End &mdash;";
                        storyContainer.appendChild(end);
                    }

                    // Smooth scroll to newly added elements
                    var lastChild = storyContainer.lastElementChild;
                    if (lastChild) {
                        lastChild.scrollIntoView({ behavior: 'smooth', block: 'end' });
                    }
                }

                function loadStory(input, preserveState = true) {
                    try {
                        const storyData = (typeof input === 'string') ? JSON.parse(input) : input;
                        var savedState = preserveState && story ? story.state.toJson() : null;
                        
                        story = new inkjs.Story(storyData);
                        clearStory();
                        
                        if (savedState) {
                            try {
                                story.state.LoadJson(savedState);
                                storyLog.forEach(renderElement);
                            } catch(e) {
                                log("State incompatible, resetting.");
                                storyLog = [];
                                choiceHistory = [];
                            }
                        } else {
                            storyLog = [];
                            choiceHistory = [];
                        }
                        
                        continueStory();
                    } catch (e) {
                        log("Error: " + e);
                    }
                }

                window.updateStory = function(json) { loadStory(json, true); };
                window.restartStory = function() { loadStory(storyContent, false); };
                window.undoStory = function() {
                    if (choiceHistory.length > 0) {
                        choiceHistory.pop();
                        
                        story = new inkjs.Story(storyContent);
                        
                        storyLog = [];
                        var targetHistory = [...choiceHistory];
                        choiceHistory = []; 
                        
                        while(story.canContinue) {
                            var t = story.Continue();
                            storyLog.push({text: t, tags: story.currentTags});
                        }
                        
                        targetHistory.forEach(idx => {
                            story.ChooseChoiceIndex(idx);
                            choiceHistory.push(idx);
                            while(story.canContinue) {
                                var t = story.Continue();
                                storyLog.push({text: t, tags: story.currentTags});
                            }
                        });
                        
                        clearStory();
                        storyLog.forEach(renderElement);
                        renderChoices(story.currentChoices);
                    }
                };

                function showError(msg) {
                    clearStory();
                    storyContainer.innerHTML = `<div style="color:#c00; padding:20px; border:1px solid #fcc; background:#fff5f5; border-radius:8px;"><strong>Error:</strong><pre style="white-space:pre-wrap;">${msg}</pre></div>`;
                }

                // Boot
                var trimmedContent = storyContent.trim();
                if (trimmedContent.startsWith('{')) {
                    loadStory(trimmedContent, false);
                } else if (trimmedContent.startsWith('COMPILER_ERROR:')) {
                    showError(trimmedContent.substring(15));
                } else if (trimmedContent.length > 0) {
                    storyContainer.innerHTML = "<p><em>Compiling...</em></p>";
                } else {
                    storyContainer.innerHTML = "<p style='color:#999; text-align:center;'>Start writing your Ink story.</p>";
                }
                
                if (window.webkit && window.webkit.messageHandlers.inkiesBridge) {
                    window.webkit.messageHandlers.inkiesBridge.postMessage({ action: "ready" });
                }
            })();
        </script>
    </body>
    </html>
    """
}
