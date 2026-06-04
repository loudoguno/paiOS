import Foundation

enum Fallback {  // Offline reply library — used when the on-device model is unreachable.
    // 1. Spinner gerunds — the whimsical rotating words Claude Code shows while thinking.
    static let spinnerWords: [String] = [
        "Cogitating",
        "Pondering",
        "Conjuring",
        "Noodling",
        "Percolating",
        "Ruminating",
        "Marinating",
        "Simmering",
        "Brewing",
        "Synthesizing",
        "Wrangling",
        "Finagling",
        "Herding",
        "Vibing",
        "Spelunking",
        "Transmuting",
        "Incanting",
        "Manifesting",
        "Reticulating",
        "Discombobulating",
        "Schlepping",
        "Moseying",
        "Puzzling",
        "Channelling",
        "Mulling",
        "Tinkering",
        "Hatching",
        "Untangling",
        "Calibrating",
        "Bamboozling",
        "Galvanizing",
        "Whittling",
        "Distilling",
        "Foraging",
        "Germinating",
        "Caffeinating",
        "Deliberating",
        "Smushing",
        "Crystallizing",
        "Orchestrating",
        "Effervescing",
        "Jamming",
        "Plotting",
        "Tessellating",
        "Wiggling",
        "Bedazzling",
        "Concocting",
        "Frobnicating",
        "Hammering",
        "Tumbling"
    ]

    // Fallback replies, in Claude Code's voice, for when Apple Intelligence is unavailable.
    static let responses: [String] = [
        "Done. I traced it through the render path — the token count was reading from a stale cache instead of the live session meter.\n  • StatusLine.ts — pull the count from the active session\n  • cache.ts — invalidate on each turn\n  StatusLine.ts (+14 -3), cache.ts (+2 -1)\nVerified against the last three sessions; the numbers line up now. Want me to push to mxb?",
        "Walked the hook chain and found the race: SessionStart was firing after LoadContext on a cold boot, so the first prompt saw an empty context.\n  settings.json (+4 -1)\nReordered the registration and added a guard. Ran it ten cold boots in a row — clean every time. Anything else you want hardened?",
        "Implemented it end to end:\n  • parse the flag\n  • thread it through the orchestrator\n  • add a fallback when it's missing\n  3 files changed (+47 -12)\nbun test is green, 51 passing. I left the old path behind a deprecation warning so nothing breaks downstream. Ship it?",
        "Quick decision before I commit — the change touches a load-bearing hook that three skills depend on. I can either (a) patch it in place and run the full suite, or (b) fork a v2 and migrate callers one at a time. (b) is safer but slower. Which way do you want to go?",
        "Found the leak. A Timer in the throbber kept a strong ref to the view model, so it never deallocated between turns.\n  PAIEngine.swift (+3 -1)\nSwitched it to a weak capture and cancelled it on teardown. Instruments shows the allocation graph flat now across 20 turns. Fixed.",
        "Wired the new voice into the notify path and confirmed it round-trips through the queue.\n  notify.ts (+9 -0)\nFired a test event — it spoke in about 600ms. Want me to set it as the default, or keep it opt-in behind a flag?",
        "Refactored the script into a proper CLI with subcommands and a --dry-run.\n  deploy.ts (+38 -19)\nTry: deploy --dry-run --target mxb\nIt prints the plan without touching anything. I also added a confirm prompt before the destructive step. Looks good on my end.",
        "Read the config and reproduced it. Your statusline width caps at 44 columns, so the file list truncates with the ellipsis once you load more than five.\n  StatusLine.ts (+6 -2)\nI made the list wrap to a second line instead of clipping. Reads cleanly now. Deploy?",
        "Rebuilt with tree-shaking on and the bundle dropped noticeably.\n  before 84kb → after 71kb\nNo runtime behavior changed; I diffed the output AST to be sure. Want me to wire this into the CI build step so it stays lean?",
        "Almost there — one type error left in the egress inspector where the payload can be unknown at the boundary.\n  inspectors/EgressInspector.ts (+5 -2)\nI narrowed it with a guard instead of casting, so we don't lose safety. Compiles clean now. Running the suite to confirm nothing regressed."
    ]

    // 3. Tool-call "action" lines that appear BEFORE a response.
    static let toolLines: [String] = [
        "\u{25CF} Read(StatusLine.ts)",
        "\u{25CF} Bash(bun test)",
        "\u{25CF} Edit(Theme.swift)",
        "\u{25CF} Grep(\"throbber\")",
        "\u{25CF} Write(deploy.md)",
        "\u{25CF} Bash(bun run build)",
        "\u{25CF} Read(settings.json)",
        "\u{25CF} Edit(notify.ts)",
        "\u{25CF} Grep(\"port 3000\")",
        "\u{25CF} Bash(git status)",
        "\u{25CF} Read(hooks/LoadContext.ts)",
        "\u{25CF} Write(PAIStatusLine.swift)",
        "\u{25CF} Edit(pulse.ts)",
        "\u{25CF} Bash(git commit -m)",
        "\u{25CF} Grep(\"interval\")",
        "\u{25CF} Read(PULSE.toml)"
    ]

    // 4. Startup tips — one-liner tips printed on launch (no "Tip:" prefix).
    static let tips: [String] = [
        "Use natural language to describe what you want to build.",
        "Raise your wrist and just start talking.",
        "Say \"undo\" to revert the last edit.",
        "Ask for a plan before you ask for the code.",
        "Tap a tool line to expand the full diff.",
        "Short, specific asks get faster, cleaner results.",
        "Say \"run the tests\" to verify before you ship.",
        "Long-press to interrupt a running task."
    ]

    // A realistic in-progress exchange so the app looks like a live session on open.
    static let seedConversation: [Line] = [
        Line(role: .user, text: "add a remote-control badge to my statusline"),
        Line(role: .tool, text: "\u{25CF} Read(StatusLine.ts)"),
        Line(role: .tool, text: "\u{25CF} Edit(StatusLine.ts)"),
        Line(role: .assistant, text: "Added a green \u{201C}Remote Control active\u{201D} badge wired to the live session state.\n  StatusLine.ts (+8 -1)\nDeployed to mxb \u{2014} you\u{2019}re driving it from your wrist now.")
    ]
}
