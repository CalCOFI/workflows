// cc-vector-basemap: draw CARTO basemaps from their vector GL styles in Leaflet.
//
// CARTO's raster basemaps (light_all, dark_all, rastertiles/voyager, ...) answer every tile
// with an "API KEY REQUIRED" watermark since Sep 2026; its vector GL styles
// (basemaps.cartocdn.com/gl/{style}-gl-style/style.json) do not. This swaps any CARTO raster
// layer a Leaflet map asks for, by provider name (`L.tileLayer.provider("CartoDB.Positron")`,
// as R leaflet's addProviderTiles() and mapview's default basemaps do) or by URL
// (`L.tileLayer("https://{s}.basemaps.cartocdn.com/light_all/...")`), for the same style drawn
// by maplibre-gl-leaflet. Every other tile layer passes through untouched.
//
// Needs Leaflet, maplibre-gl and @maplibre/maplibre-gl-leaflet loaded first. Idempotent.
(function () {
  "use strict";
  var L = window.L;
  if (!L || !L.tileLayer || !L.maplibreGL || L.ccVectorBasemap) return;

  // stack the GL containers like tile layers: maplibre-gl.css makes .maplibregl-map
  // `position: relative`, so without this a second GL layer (a layer-control switch, a
  // labels overlay) flows below the first, outside the map
  var css = document.createElement("style");
  css.textContent = ".leaflet-pane > .leaflet-gl-layer.maplibregl-map{position:absolute;left:0;top:0}";
  document.head.appendChild(css);

  var GL = "https://basemaps.cartocdn.com/gl/";
  var ATTRIBUTION =
    '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors ' +
    '&copy; <a href="https://carto.com/attributions">CARTO</a>';

  // a provider name or a tile url -> {style, labels} or null when it is not a CARTO raster
  function cartoStyle(s) {
    s = String(s || "");
    var is_name = /^CartoDB(\.|$)/.test(s);
    var is_url = /basemaps\.cartocdn\.com\/(light_|dark_|rastertiles\/)|cartodb-basemaps-[a-z{}]+\.global\.ssl\.fastly\.net/.test(s);
    if (!is_name && !is_url) return null;
    var style = /dark/i.test(s) ? "dark-matter" : /voyager/i.test(s) ? "voyager" : "positron";
    var labels = /only_?labels/i.test(s) ? "only" : /no_?labels/i.test(s) ? "none" : "all";
    return { style: style, labels: labels };
  }

  function styleUrl(c) {
    return GL + c.style + (c.labels === "none" ? "-nolabels" : "") + "-gl-style/style.json";
  }

  // a labels-only layer is the full style with every non-symbol layer hidden, so it can sit
  // above the data (in a label pane) without covering it
  function hideNonSymbol(gl) {
    var layers = (gl.getStyle() || {}).layers || [];
    layers.forEach(function (ly) {
      if (ly.type !== "symbol" && (ly.layout || {}).visibility !== "none")
        gl.setLayoutProperty(ly.id, "visibility", "none");
    });
  }

  function vectorLayer(c, options) {
    options = options || {};
    var layer = L.maplibreGL({
      style:       styleUrl(c),
      pane:        options.pane || "tilePane",
      attribution: options.attribution === "" ? "" : ATTRIBUTION,
      interactive: false,
      // the zoom bounds a tile layer sets on its map: without them the map's maxZoom is
      // Infinity and Leaflet.markercluster fails ("reading '_addChild'"), clusters gone
      minZoom:     options.minZoom != null ? options.minZoom : 0,
      maxZoom:     options.maxZoom != null ? options.maxZoom : 20
    });
    layer.ccCarto = c;
    // register those bounds the way L.GridLayer does (beforeAdd / onRemove)
    layer.beforeAdd = function (map) {
      if (map._addZoomLimit) map._addZoomLimit(layer);
    };
    var onRemove = layer.onRemove;
    layer.onRemove = function (map) {
      onRemove.call(layer, map);
      if (map._removeZoomLimit) map._removeZoomLimit(layer);
    };
    if (c.labels === "only") {
      layer.on("add", function () {
        var gl = layer.getMaplibreMap();
        // style.load, not styledata: setLayoutProperty() itself fires styledata
        if (gl.isStyleLoaded()) hideNonSymbol(gl);
        gl.on("style.load", function () { hideNonSymbol(gl); });
      });
    }
    if (options.opacity != null && options.opacity < 1) {
      layer.on("add", function () {
        var el = layer.getContainer && layer.getContainer();
        if (el) el.style.opacity = options.opacity;
      });
    }
    // a theme flip in an app calls setUrl() on its basemap; follow it with the matching style
    layer.setUrl = function (url) {
      var c2 = cartoStyle(url);
      if (!c2) return layer;
      var gl = layer.getMaplibreMap && layer.getMaplibreMap();
      if (gl) gl.setStyle(styleUrl(c2));
      else layer.options.style = styleUrl(c2);
      return layer;
    };
    return layer;
  }

  // L.tileLayer is a factory carrying .provider and .wms; keep them on the wrapper
  var tileLayer = L.tileLayer;
  var wrapped = function (url, options) {
    var c = cartoStyle(url);
    return c ? vectorLayer(c, options) : tileLayer.apply(this, arguments);
  };
  for (var k in tileLayer) {
    if (Object.prototype.hasOwnProperty.call(tileLayer, k)) wrapped[k] = tileLayer[k];
  }
  L.tileLayer = wrapped;

  if (tileLayer.provider) {
    var provider = tileLayer.provider;
    L.tileLayer.provider = function (name, options) {
      var c = cartoStyle(name);
      return c ? vectorLayer(c, options) : provider.apply(this, arguments);
    };
  }

  L.ccVectorBasemap = { cartoStyle: cartoStyle, styleUrl: styleUrl, layer: vectorLayer };
})();
