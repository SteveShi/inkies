//
//  InkSnippets.swift
//  inkies
//
//  Ink code snippets for the Ink menu, replicating Inky's functionality.
//

import Foundation

struct InkSnippet {
    let name: String
    let ink: String

    var localizedName: String {
        String(localized: String.LocalizationValue(name))
    }

    static func fromFile(name: String, filename: String) -> InkSnippet {
        // Search more broadly for the resource
        let possibleUrls = [
            Bundle.main.url(forResource: filename, withExtension: "ink", subdirectory: "Examples"),
            Bundle.main.url(forResource: filename, withExtension: "ink"),
            Bundle.main.url(forResource: "Resources/Examples/\(filename)", withExtension: "ink"),
            Bundle.main.url(forResource: "Examples/\(filename)", withExtension: "ink")
        ]
        
        let url = possibleUrls.compactMap { $0 }.first

        if let url = url, let content = try? String(contentsOf: url, encoding: .utf8) {
            return InkSnippet(name: name, ink: content)
        }
        
        print("INKIES DEBUG: Failed to load snippet file: \(filename).ink")
        return InkSnippet(name: name, ink: "// Error: Could not load \(filename).ink from bundle. Please check if the file is included in the project resources.")
    }
}

struct InkSnippetCategory {
    let name: String
    let snippets: [InkSnippet]

    var localizedName: String {
        String(localized: String.LocalizationValue(name))
    }
}

// MARK: - All Ink Snippets (Matching Inky)
struct InkSnippets {

    // MARK: - Basic Structure
    static let basicStructure = InkSnippetCategory(
        name: "Basic structure",
        snippets: [
            InkSnippet(
                name: "Knot (main section)",
                ink: """
                    === knotName ===
                    This is the content of the knot.
                    -> END

                    """
            ),
            InkSnippet(
                name: "Stitch (sub-section)",
                ink: """
                    = stitchName
                    This is the content of the stitch that should be embedded within a knot.
                    -> END

                    """
            ),
            InkSnippet(
                name: "Divert",
                ink: "-> targetKnotName"
            ),
            InkSnippet(
                name: "Ending indicator",
                ink: "-> END\n"
            ),
        ]
    )

    // MARK: - Choices
    static let choices = InkSnippetCategory(
        name: "Choices",
        snippets: [
            InkSnippet(
                name: "Basic Choice",
                ink: "* This is a choice that can only be chosen once\n"
            ),
            InkSnippet(
                name: "Sticky choice",
                ink: "+ This is a sticky choice - the player can choose it more than once\n"
            ),
            InkSnippet(
                name: "Choice without printing",
                ink: "* [A choice where the content isn't printed after choosing]\n"
            ),
            InkSnippet(
                name: "Choice with mixed output",
                ink: "* Try [it] this example!\n"
            ),
        ]
    )

    // MARK: - Variables
    static let variables = InkSnippetCategory(
        name: "Variables",
        snippets: [
            InkSnippet(
                name: "Global variable",
                ink: "VAR myNumber = 5\n"
            ),
            InkSnippet(
                name: "Temporary variable",
                ink: "temp myTemporaryValue = 5\n"
            ),
            InkSnippet(
                name: "Modify variable",
                ink: "~ myNumber = myNumber + 1\n"
            ),
            InkSnippet(
                name: "Get variable type",
                ink: """
                    === function type_of(x)
                        { x:
                            { "{x}" != "{x}":
                                ~ return "divert"
                            - "{LIST_ALL(x)}" != "":
                                ~ return "list"
                            - x != "{x}":
                                ~ return "number"
                            - else:
                                ~ return "string"
                            }
                        - else:
                            ~ return "null"
                        }

                    """
            ),
        ]
    )

    // MARK: - Inline Logic
    static let inlineLogic = InkSnippetCategory(
        name: "Inline logic",
        snippets: [
            InkSnippet(
                name: "Condition",
                ink:
                    "{yourVariable: This is written if yourVariable is true|Otherwise this is written}"
            )
        ]
    )

    // MARK: - Multi-line Logic
    static let multilineLogic = InkSnippetCategory(
        name: "Multi-line logic",
        snippets: [
            InkSnippet(
                name: "Condition",
                ink: """
                    {yourVariable:
                        This is written if yourVariable is true.
                      - else:
                        Otherwise this is written.
                    }

                    """
            )
        ]
    )

    // MARK: - Comments
    static let comments = InkSnippetCategory(
        name: "Comments",
        snippets: [
            InkSnippet(
                name: "Single-line comment",
                ink: "// This line is a comment.\n"
            ),
            InkSnippet(
                name: "Block comment",
                ink: """
                    /* ---------------------------------

                       This whole section is a comment 

                     ----------------------------------*/

                    """
            ),
        ]
    )

    // MARK: - List Handling
    static let listHandling = InkSnippetCategory(
        name: "List-handling",
        snippets: [
            InkSnippet(
                name: "List: pop",
                ink: """
                    === function pop(ref list)
                        ~ temp x = LIST_MIN(list) 
                        ~ list -= x
                        ~ return x

                    """
            ),
            InkSnippet(
                name: "List: pop_random",
                ink: """
                    === function pop_random(ref list)
                        ~ temp x = LIST_RANDOM(list) 
                        ~ list -= x 
                        ~ return x

                    """
            ),
            InkSnippet(
                name: "List: LIST_NEXT and LIST_PREV",
                ink: """
                    === function LIST_NEXT(x) 
                        ~ return LIST_RANGE(LIST_ALL(x), x, LIST_MAX(LIST_ALL(x))) - x
                        
                    === function LIST_PREV(x) 
                        ~ return LIST_RANGE(LIST_ALL(x), LIST_MIN(LIST_ALL(x)), x) - x

                    """
            ),
            InkSnippet(
                name: "List: list_item_is_member_of",
                ink: """
                    === function list_item_is_member_of(item, list)
                        ~ return LIST_COUNT(list ^ item) > 0

                    """
            ),
            InkSnippet(
                name: "List: list_random_subset",
                ink: """
                    === function list_random_subset(list)
                        { list:
                            ~ temp include_this = RANDOM(0, 1)
                            ~ temp x = LIST_MIN(list)
                            { include_this:
                                ~ return x + list_random_subset(list - x)
                            - else:
                                ~ return list_random_subset(list - x)
                            }
                        - else:
                            ~ return ()
                        }

                    """
            ),
        ]
    )

    // MARK: - Useful Functions
    static let usefulFunctions = InkSnippetCategory(
        name: "Useful functions",
        snippets: [
            InkSnippet(
                name: "Logic: maybe",
                ink: """
                    === function maybe(p)
                        ~ return RANDOM(1, 100) <= p

                    """
            ),
            InkSnippet(
                name: "Mathematics: divisor",
                ink: """
                    === function divisor(x, n)
                    ~ return (x - x mod n) / n
                    """
            ),
            InkSnippet(
                name: "Mathematics: abs",
                ink: """
                    === function abs(x)
                    { x < 0:
                          ~ return -1 * x
                      - else: 
                          ~ return x
                    }
                    """
            ),
            InkSnippet(
                name: "Flow: came_from",
                ink: """
                    === function came_from(-> x) 
                        ~ return TURNS_SINCE(x) == 0

                    """
            ),
            InkSnippet(
                name: "Flow: seen_very_recently",
                ink: """
                    === function seen_very_recently(-> x)
                        ~ return TURNS_SINCE(x) >= 0 && TURNS_SINCE(x) <= 3

                    """
            ),
            InkSnippet(
                name: "Flow: seen_more_recently_than",
                ink: """
                    === function seen_more_recently_than(-> a, -> b)
                        ~ return TURNS_SINCE(a) >= 0 && TURNS_SINCE(a) < TURNS_SINCE(b)

                    """
            ),
            InkSnippet(
                name: "Printing: a (or an)",
                ink: """
                    === function a(word)
                        ~ temp firstLetter = "{word}"
                        { firstLetter == "a" or firstLetter == "e" or firstLetter == "i" or firstLetter == "o" or firstLetter == "u":
                            an {word}
                        - else:
                            a {word}
                        }

                    """
            ),
            InkSnippet(
                name: "Printing: UPPERCASE",
                ink: """
                    === function UPPERCASE(x)
                        ~ return "{x}" // Ink doesn't have native uppercase, use external function

                    """
            ),
            InkSnippet(
                name: "Printing: list_with_commas",
                ink: """
                    === function list_with_commas(list)
                        { LIST_COUNT(list) == 0:
                            ~ return ""
                        }
                        ~ temp first = LIST_MIN(list)
                        ~ temp remaining = list - first
                        { LIST_COUNT(remaining) == 0:
                            ~ return "{first}"
                        - LIST_COUNT(remaining) == 1:
                            ~ return "{first} and {LIST_MIN(remaining)}"
                        - else:
                            ~ return "{first}, {list_with_commas(remaining)}"
                        }

                    """
            ),
        ]
    )

    // MARK: - Useful Systems
    static let usefulSystems = InkSnippetCategory(
        name: "Useful systems",
        snippets: [
            InkSnippet(
                name: "List Items as Integer Variables",
                ink: """
                    // Use list items to store integer values
                    LIST health_points = (hp0), hp1, hp2, hp3, hp4, hp5, hp6, hp7, hp8, hp9, hp10
                    VAR health = (hp5)  // Starting with 5 health

                    === function get_health()
                        ~ return LIST_VALUE(health) - LIST_VALUE(hp0)

                    === function set_health(val)
                        ~ health = LIST_RANGE(health_points, hp0, hp0) // reset
                        ~ temp i = 0
                        { val > 0:
                            - loop:
                            ~ health = LIST_NEXT(health)
                            ~ i++
                            { i < val: -> loop }
                        }

                    """
            ),
            InkSnippet(
                name: "Swing Variables",
                ink: """
                    // A variable that swings between -3 and +3
                    VAR trust = 0

                    === function adjust_trust(amount)
                        ~ trust = trust + amount
                        { trust > 3:
                            ~ trust = 3
                        - trust < -3:
                            ~ trust = -3
                        }

                    === function trust_level()
                        { trust >= 2:
                            ~ return "trusting"
                        - trust >= 0:
                            ~ return "neutral"
                        - else:
                            ~ return "suspicious"
                        }

                    """
            ),
            InkSnippet(
                name: "Storylets",
                ink: """
                    // Simple storylet system
                    LIST storylets = (story_a), story_b, story_c
                    VAR available_storylets = ()

                    === function refresh_storylets()
                        ~ available_storylets = ()
                        { not story_a:
                            ~ available_storylets += story_a
                        }
                        { not story_b && seen_a:
                            ~ available_storylets += story_b
                        }
                        ~ return available_storylets

                    VAR seen_a = false

                    === story_a
                    ~ seen_a = true
                    This is storylet A.
                    -> DONE

                    === story_b
                    This is storylet B, available after A.
                    -> DONE

                    """
            ),
        ]
    )

    // MARK: - Full Stories
    static let fullStories = InkSnippetCategory(
        name: "Full stories",
        snippets: [
            InkSnippet.fromFile(name: "The Intercept (Inky Example)", filename: "theintercept"),
            InkSnippet.fromFile(name: "Swindlestones (Inky Example)", filename: "swindlestones"),
            InkSnippet.fromFile(name: "Murder Scene (Inky Example)", filename: "murder_scene"),
            InkSnippet.fromFile(name: "Crime Scene (Original)", filename: "crime_scene"),
            InkSnippet.fromFile(name: "Dialogue Example (Original)", filename: "dialogue_example"),
        ]
    )

    // MARK: - All Categories
    static let allCategories: [InkSnippetCategory] = [
        basicStructure,
        choices,
        variables,
        inlineLogic,
        multilineLogic,
        comments,
        listHandling,
        usefulFunctions,
        usefulSystems,
        fullStories,
    ]
}
