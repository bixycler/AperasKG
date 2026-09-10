# Documentation Architecture — Discussion <a name='id/BlockNode:00CDD68EV8001' class='aperas-anchor aperas-id'></a>

## Motivation: The Mixing Problem <a name='id/BlockNode:00CDD68EV8002' class='aperas-anchor aperas-id'></a>

Currently, documents in `AperasKG/artifacts/` are massive mixtures of completely different logical concerns. Looking at actual project files (e.g., `Aperas-crud-design.md` and `Aperas-treeview-design.md`), the writer often mixes everything into a single document and sometimes even the same paragraph.

No transducer or adapter can automatically untangle this. A single artifact today contains:

- **Core Design:** The actual specification (e.g., `3. Core model: placeholder is a flag`).
- **Issues & Gaps:** Bugs discovered live during implementation (e.g., `6. Bookkeeping gaps found while designing this`).
- **History & Status:** Implementation progress and verification records (e.g., `Status: implemented, live-verified against a synthetic graph`).
- **Discussion & Rationale:** Why something was built a certain way, or rejected (e.g., `12. Considered and rejected`).
- **Implementation Details:** Notes to self about code structure.

This is the evidence base for adopting block-based separation of concerns (see [Architecture](../design/documentation.md#id/BlockNode:00CDD68E80007)): splitting design, issues, planning, history, and discussion into strictly isolated documents so a reader parsing a Design doc sees only the design.
