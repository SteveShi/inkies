import Foundation

// MARK: - HTML Generator Helpers

// Helper to find the InkJS library
func getInkScript() -> String {
    if let path = Bundle.main.path(forResource: "ink.min", ofType: "js", inDirectory: "Scripts") {
        if let content = try? String(contentsOfFile: path, encoding: .utf8) {
            print("INKIES DEBUG: local ink.min.js loaded successfully (\(content.count) bytes)")
            return
                "<script>/* InkJS included from Bundle (\(content.count) bytes) */\n\(content)</script>"
        } else {
            print("INKIES DEBUG: ERROR - local ink.min.js found but failed to read")
            return
                "<script>console.error('INKIES DEBUG: local ink.min.js found but failed to read');</script>"
        }
    }
    // Fallback to CDN if local file not found (User needs to add it to bundle)
    print("INKIES DEBUG: WARNING - local ink.min.js NOT found in bundle, using CDN fallback")
    return
        #"<script src="https://unpkg.com/inkjs/dist/ink.js"></script><script>console.warn('INKIES DEBUG: local ink.min.js NOT found in bundle, using CDN');</script>"#
}

func generateHTML(
    for inkContext: String, theme: AppTheme, enableIncrementalUpdate: Bool = false
) -> String {
    let safeContent = inkContext.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "")

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
                
                /* Custom Classes from tags #CLASS: name */
                .italic { font-style: italic; }
                .bold { font-weight: bold; }
                .centered { text-align: center; }
            </style>
        </head>
        <body class="\(theme == .dark ? "dark" : "light")">
            <div id="outer-container">
                <div id="story"></div>
            </div>

            <script>
                (function() {
                    var storyContent = "\(safeContent)";
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
                        // Don't skip if there are tags, as they might be doing things (like IMAGE: or CLASS:)
                        if (obj.text.trim().length === 0 && obj.tags.length === 0) return;
                        
                        var p = document.createElement('p');
                        
                        // Handle #CLASS: name tags
                        obj.tags.forEach(function(tag) {
                            if (tag.startsWith("CLASS:")) {
                                p.classList.add(tag.substring(6).trim().toLowerCase());
                            }
                            if (tag.startsWith("IMAGE:")) {
                                var img = document.createElement('img');
                                img.src = tag.substring(6).trim();
                                storyContainer.appendChild(img);
                            }
                        });

                        p.innerHTML = obj.text;
                        
                        // Show other tags? 
                        // User thinks rendering #title as text is "obviously wrong".
                        // Standard practice: tags are metadata, not story content.
                        /*
                        obj.tags.forEach(function(tag) {
                            if (!tag.startsWith("CLASS:") && !tag.startsWith("IMAGE:")) {
                                var span = document.createElement('span');
                                span.classList.add('tag');
                                span.innerText = '#' + tag;
                                p.appendChild(span);
                            }
                        });
                        */
                        
                        storyContainer.appendChild(p);
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
                                    // Re-render the existing log
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
                            // Deep reset and replay to rebuild state exactly
                            loadStory(storyContent, false); 
                            var targetHistory = [...choiceHistory];
                            choiceHistory = []; // Reset during replay
                            targetHistory.forEach(idx => {
                                story.ChooseChoiceIndex(idx);
                                choiceHistory.push(idx);
                                // We don't use continueStory here to avoid flicker, 
                                // just catch up the internal state
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
