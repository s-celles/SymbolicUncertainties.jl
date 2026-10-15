// Renders the `.mermaid` blocks that DocumenterMermaid emits, with a
// pinned mermaid that predates the 11.17 regression.
//
// DocumenterMermaid imports the floating `mermaid@11` tag. Since
// 11.17.0 that bundle inlines `fastdom`, whose UMD wrapper hands
// itself to any global `define()` — and Documenter's HTML output
// always loads RequireJS — so mermaid's own import of it comes back
// empty and the import throws `Se.default.extend is not a function`
// before a single diagram is drawn. See `upstream-bugs.md` UB-010;
// delete this file once DocumenterMermaid pins a working version.
//
// The failed import leaves the diagrams untouched, and mermaid marks
// what it renders with `data-processed`, so nothing is drawn twice if
// DocumenterMermaid's own import starts working again.
(() => {
  const render = async () => {
    if (document.querySelectorAll(".mermaid").length === 0) {
      return;
    }
    const { default: mermaid } = await import(
      "https://cdn.jsdelivr.net/npm/mermaid@11.16.0/dist/mermaid.esm.min.mjs"
    );
    mermaid.initialize({ startOnLoad: false, theme: "neutral" });
    await mermaid.run({ querySelector: ".mermaid" });
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", render);
  } else {
    render();
  }
})();
