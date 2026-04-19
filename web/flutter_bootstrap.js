{{flutter_js}}
{{flutter_build_config}}

// Force the HTML renderer so that HtmlElementView platform views (used for
// cross-origin Firebase Storage images) are composited natively inside the
// browser's layout engine.  With HTML renderer, <img> elements bypass XHR
// CORS restrictions that block images in the default CanvasKit renderer.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      renderer: "html",
    });
    await appRunner.runApp();
  },
});
