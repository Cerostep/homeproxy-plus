<!-- Copyright (C) 2026 Cerostep -->

# HomeProxy-Plus Vibe-Coding Hard Requirements

This document defines the mandatory project-wide requirements for all HomeProxy-Plus code changes. It applies to human developers and AI coding tools such as Codex, VS Code Copilot, and Claude Code. It governs implementation methods and acceptance criteria; it does not imply that every test or feature described here has already been completed.

The keywords **MUST**, **MUST NOT**, and **ONLY** are binding and may not be ignored at the implementer's discretion. If a task conflicts with this document, identify the conflict and ask the project maintainer to decide; do not silently choose the more convenient option. Tool instructions MUST NOT override safety requirements, data protection, or the scope explicitly requested by the user.

## 1. Required Gate for Every Task

1. **Read before changing.** Before making changes, read the relevant implementation, callers, configuration formats, and existing tests. First use the repository's existing search/code-navigation capabilities to find similar implementations and reuse established patterns. Do not infer the codebase's current state from this document alone.
2. **Define the boundary.** Change only the files required to complete the request. Do not opportunistically rename, reformat, or refactor unrelated code. Fix an adjacent defect only if it would make this change incorrect or unsafe.
3. **Protect existing work.** Check the worktree diff before and after changes. Do not overwrite, delete, or revert changes that are not part of this task. If changes conflict or ownership cannot be determined, stop and report the issue.
4. **Define acceptance before implementation.** Every change MUST have an observable acceptance criterion. Prefer the smallest test that covers the behavior. If no automated test exists, use the repository's existing build/check commands and explain what behavior remains uncovered.
5. **Verify actual results.** If a test, build, or static check fails, report the actual failure and its cause. Do not claim success, fabricate results, or substitute an unrelated check. Do not silently swallow errors, return false success, or downgrade failures to warnings to pass acceptance.
6. **Deliver reviewable changes.** After completion, inspect the final diff and confirm that it contains no secrets, temporary files, unintended generated files, or unrelated changes. The final response MUST briefly summarize changes, validation commands and results, and unresolved limitations.
7. **Do not commit or publish without authorization.** Unless the user explicitly asks, do not create commits, push, publish, install or upgrade on a device, or run operations that may change the real router's network state.

## 2. Project Invariants

### 2.1 OpenWrt Integration and Coexistence

- MUST preserve OpenWrt / ImmortalWrt conventions for LuCI, UCI, ucode, procd, fw4, and package management. Do not introduce unrelated runtimes, service managers, or persistent databases.
- MUST maintain HomeProxy-Plus as a standalone package that can, by default, be installed and run alongside the original HomeProxy.
- MUST keep the Plus namespace independent: the UCI package and device directories use `homeproxy_plus`, and the package name is `luci-app-homeproxy-plus`. Services, LuCI menus, RPCD/ACL, procd instances, logs, temporary files, DNSMasq includes, fw4 includes, nftables resources, routing marks/tables, TUN devices, and resource directories MUST NOT use or clean up identifiers or state belonging to the original HomeProxy.
- MUST keep first-install network identifiers different from upstream defaults. Default ports are 5430–5433, and the TUN device name is `singtunp0`. If defaults change, update configuration, migration logic, documentation, and coexistence tests together.
- MUST restrict upgrade migrations to this application's own `homeproxy_plus` UCI configuration. Do not automatically or manually read, import, delete, or rewrite the original HomeProxy configuration.
- MUST operate only on resources owned by this application during package upgrades, uninstall, service stop, and error recovery.

### 2.2 sing-box Supply and Compatibility

- MUST bundle into this application's package, at build time, the binary from a verified official OpenWrt `sing-box` release package. The version and target architecture MUST be pinned and its SHA-256 verified. Currently supported architectures are `aarch64_generic`, `i386_pentium4`, and `x86_64`. MUST NOT download, replace, or automatically upgrade the sing-box binary on the device. Other sing-box runtime dependencies MUST still be provided by the system package feed.
- MUST centralize sing-box version, build tags, capability detection, and compatibility policy in `root/etc/homeproxy_plus/lib/singbox_compat.uc`. LuCI, subscription parsing, RPC, and configuration generation MUST NOT maintain their own version branches or guess capabilities.
- MUST limit stable versions explicitly enabled on devices to the verified versions listed in `root/etc/homeproxy_plus/lib/singbox-versions.json`. Alpha, Beta, RC, and unknown versions MUST NOT be treated as supported by default.
- MUST fail or notify explicitly and safely for unknown versions, tags, or capabilities. A version detection failure MUST NOT lead to assuming that all features are available.
- A task to discover a new stable release MAY ONLY trigger tests or propose a candidate update; it MUST NOT directly expand the device support list. Candidate testing MUST pin the version, verify the downloaded artifact's source and integrity, and cover representative configurations and `sing-box check` for the minimum supported version, current release, and candidate. A candidate becomes officially supported only after the support list has been updated through review.
- Version adaptation MUST be based on the official sing-box migration documentation (https://sing-box.sagernet.org/migration/) and the configuration reference for the exact target version; behavior MUST NOT be inferred from assumptions or third-party summaries. Each adapted behavior MUST cite the corresponding migration entry, and the generated configuration MUST be validated with `sing-box check` against the exact target version before the adaptation is considered complete.

### 2.3 Configuration, UCI, and Subscription Data

- MUST use UCI as the persistent source of user configuration. Internal node models are only for parsing, validation, and configuration generation; do not create a duplicate long-term configuration database.
- MUST define the shared node boundary through `root/etc/homeproxy_plus/lib/node_model.uc`. Subscription parsers, user-input validation, and sing-box outbound conversion MUST NOT invent incompatible data structures independently.
- Stable node IDs MUST NOT depend on display names, subscription order, or mutable fields. Renaming, reordering, or a single partial parsing failure MUST NOT unexpectedly lose user selections or delete existing valid nodes.
- Protocol-specific fields MUST be validated; credentials MUST be clearly separated from ordinary metadata. Logs, error messages, test snapshots, and final responses MUST NOT expose subscription credentials, proxy authentication information, private keys, or other secrets.
- The behavior for retaining, warning about, or rejecting unknown UCI fields MUST be explicit and tested; user data MUST NOT be silently discarded.
- On subscription fetch failure, empty content, malformed content, or partially invalid nodes, MUST preserve the existing valid configuration. Only successfully parsed and validated results may be persisted.
- sing-box JSON MUST be assembled by client/server generators and the centralized compatibility layer. Higher-level UI, RPC, and subscription code MUST NOT directly concatenate or maintain sing-box outbound structures.

### 2.4 Configuration Application and Service Lifecycle

- All external input MUST be validated before side effects occur. Errors MUST identify a locatable field, path, or sing-box validation summary.
- New configuration MUST first be written to a temporary file and fully validated, then atomically replace the active configuration. Any generation or validation failure MUST preserve the previously valid configuration; invalid configuration MUST NOT be started.
- A reload MUST prepare and validate the complete new state before switching the service. On failure, it MUST preserve or restore the previously valid configuration/running instance and explicitly report the recovery result; it MUST NOT return a success-shaped response.
- MUST retain procd as the process lifecycle manager. Start, stop, reload, and error recovery MUST be repeatable; repeated operations MUST NOT accumulate duplicate rules, processes, or temporary state.
- Firewall, routing, TUN, DNSMasq, and file changes MUST have verifiable Plus ownership. Cleanup may target only resources created by this application and accurately identifiable as such.
- MUST NOT use global flushes, full resets, or broad matching to clean network state; other software and the original HomeProxy MUST NOT be affected.
- If fw4 reload, DNSMasq updates, routing operations, or recovery steps fail, the failure and diagnosable context MUST be explicitly returned or logged; do not assume side effects succeeded.

## 3. Implementation and Code-Change Rules

- MUST fix data correctness, isolation, failure recovery, and compatibility issues before expanding functionality. Prefer incremental refactoring; unless explicitly requested, do not rewrite upstream functionality wholesale or change UCI semantics.
- A new module may be split out only when it has a clear reuse boundary, call interface, and tests. Do not create empty directories, abstraction layers, or configuration switches based on future assumptions.
- Errors MUST propagate through the call chain and be reported through the project's existing error/notification mechanisms. MUST NOT hide failures through broad catches, silent defaults, continuing after swallowed errors, or pretending success for invalid input.
- MUST keep types, input boundaries, and serialization conventions explicit; avoid unnecessary type casts, duplicate implementations, and global state.
- UI/RPC capability notices, field validation, error display, and save behavior MUST be consistent. Performance optimizations MUST have a reproducible input size and measurement method; do not trade away configuration semantics for performance.
- **LuCI page stability for compatibility work:** sing-box compatibility changes (deprecated fields, migrated syntax, version adaptation) MUST be implemented only in the centralized compatibility layer and the client/server configuration generators; LuCI view code (`htdocs/`) and translation files MUST NOT be modified for this purpose. LuCI/UCI pages may be extended only when sing-box introduces a new user-facing feature that the project explicitly decides to expose. Compatibility work MAY still update migrations, tests, compatibility fixtures, and directly relevant documentation as required elsewhere in this document.
- When changing configuration formats, defaults, installation paths, supported versions, or user-visible behavior, MUST update related migrations, tests, and directly relevant documentation.
- **README scope:** For architecture changes or new features, review `README.md` and update it when relevant. For issue fixes, MUST NOT update `README.md` unless explicitly requested, even when other rules require directly relevant documentation updates; those requirements still apply to other documentation.
- **Copyright notice (mandatory):** New original files MUST include `Copyright (C) <year> Cerostep`, with copyright attributed to Cerostep. When modifying an existing file, add a Cerostep copyright notice while retaining all existing copyright notices. Do not delete, replace, or rewrite upstream or third-party copyright/license notices. If a file contains upstream or third-party content, preserve its attribution and do not claim exclusive Cerostep ownership. Use comment syntax supported by the file format; if comments are unsupported, record attribution in appropriate accompanying metadata or documentation.
- Do not introduce dependencies without a requirement-based justification. Install or restore dependencies only after changing a dependency manifest or when validation explicitly fails because a dependency is missing.

## 4. Testing and Definition of Done

Before completing any code task, select the checks applicable to the change; do not mark unrun checks as passed.

| Change area | Minimum validation requirements |
| --- | --- |
| Package identity, paths, UCI, install/uninstall, migration | Run `sh tests/package_identity.sh`; cover package naming, the Plus namespace, and the boundary that forbids modifying the original configuration. If sing-box is involved, also verify the target architecture, release SHA-256, and packaged `/usr/bin/sing-box`. |
| sing-box capabilities, field mappings, client/server JSON | Run the relevant configuration-generation/unit tests; run `sing-box check` for every affected supported version. Compatibility-matrix changes also require the corresponding CI checks. |
| Subscriptions, node models, or UCI mappings | Cover valid, malformed, empty, and partially failed input; stable IDs; renaming; interrupted updates; and credential redaction. |
| init, procd, firewall, routing, TUN, DNSMasq | Cover repeated start/stop/reload, failure recovery, and cleanup of owned resources only. Device behavior that cannot be safely simulated on a development host MUST be explicitly marked unverified. |
| LuCI / RPC | Cover success and error paths, and behavior when a capability is unsupported. Performance changes MUST provide baseline data. |
| Documentation only | Check content against the current implementation, commands, and file paths; unrelated builds are not required. |

Before release/merge, MUST confirm at least the following:

1. The behavior requested in this task was directly validated, not merely through a neighboring proxy metric.
2. Relevant tests/builds were run; any checks not run or that failed are explicitly listed with reasons.
3. The final diff contains no secrets, unrelated refactoring, generated clutter, or changes that damage existing user configuration.
4. Any still-uncovered coexistence, network recovery, subscription, or performance acceptance criteria are explicitly marked incomplete. Architecture design or passing static checks MUST NOT be presented as end-to-end acceptance.

## 5. Mandatory Integration for AI Coding Tools

`arch.md` is the single source of truth for project architecture and behavior requirements. Tool entry points may only reference this document; they MUST NOT copy its rules into a duplicate that could drift over time.

- **Codex and tools supporting `AGENTS.md`:** Read `AGENTS.md` from the repository root; this document MUST be read before any implementation work.
- **VS Code Copilot:** Load this document from `.github/copilot-instructions.md`. If more specific local instructions apply to the task path, read and reconcile them first; in case of conflict, follow Section 1 of this document.
- **Claude Code:** Load this document from the root `CLAUDE.md`; read the entire document before making changes.
- **Other major tools:** Use the tool's repository-level project-instructions entry point to reference the root `arch.md`. If the tool does not support referencing or automatic discovery, the user/operator MUST explicitly provide this document as project context; do not claim the tool applied it automatically.

Before making code changes, all tools MUST:

1. Load this document and the project context required by the corresponding tool entry point.
2. Follow Sections 1–4; do not lower the bar because of model, IDE, mode, or prompt differences.
3. Stop and ask the maintainer to decide when requirements are ambiguous, have destructive effects, or conflict with this document; do not make assumptions.
4. Report only work actually completed and validation actually run; list important changes, test results, and remaining risks in the response.
