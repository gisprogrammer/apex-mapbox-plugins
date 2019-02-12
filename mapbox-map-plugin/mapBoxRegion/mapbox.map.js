/**
 * [created by isabolic sabolic.ivan@gmail.com]
 */
(function ($, x) {
    var options = {
        mapRegionContainer: null,
        mapRegionId: null,
        mapName: null,
        width: "100%",
        height: 300,
        initalView: {
            x: null,
            y: null,
            zoomLevel: null
        }
    };

    /**
     * [xDebug - PRIVATE function for debug]
     * @param  string   functionName  caller function
     * @param  array    params        caller arguments
     */
    var xDebug = function (functionName, params) {
        x.debug(this.jsName || " - " || functionName, params, this);
    };
	/**
	toWKT - A simple little function for generating Well Known Text (WKT) from a Leaflet layer.
	*/
    var toWKT = function (layer) {
        var lng, lat, coords = [];
        if (layer instanceof L.Polygon || layer instanceof L.Polyline) {
            var latlngs = layer.getLatLngs();
            for (var i = 0; i < latlngs.length; i++) {
                var latlngs1 = latlngs[i];
                if (latlngs1.length) {
                    for (var j = 0; j < latlngs1.length; j++) {
                        coords.push(latlngs1[j].lng + " " + latlngs1[j].lat);
                        if (j === 0) {
                            lng = latlngs1[j].lng;
                            lat = latlngs1[j].lat;
                        }
                    }
                }
                else {
                    coords.push(latlngs[i].lng + " " + latlngs[i].lat);
                    if (i === 0) {
                        lng = latlngs[i].lng;
                        lat = latlngs[i].lat;
                    }
                }
            };
            if (layer instanceof L.Polygon) {
                return "POLYGON((" + coords.join(",") + "," + lng + " " + lat + "))";
            } else if (layer instanceof L.Polyline) {
                return "LINESTRING(" + coords.join(",") + ")";
            }
        } else if (layer instanceof L.Marker) {
            return "POINT(" + layer.getLatLng().lng + " " + layer.getLatLng().lat + ")";
        }
    };
    /**
     * [triggerEvent     - PRIVATE handler fn - trigger apex events]
     * @param String evt - apex event name to trigger
     */
    var triggerEvent = function (evt, evtData) {
        xDebug.call(this, arguments.callee.name, arguments);
        this.container.trigger(evt, [evtData]);
        $(this).trigger(evt + "." + this.apexname, [evtData]);
    };

    /**
     * [resizeMap        - PRIVATE event handler fn -  when map bbox change]
     * @param String evt - apex event name to trigger
     */
    var bboxChangeEvt = function (evt) {
        var bbox = this.map.getBounds(),
            bboxJson = {
                "west": bbox.getWest(),
                "south": bbox.getSouth(),
                "east": bbox.getEast(),
                "north": bbox.getNorth(),
                "string": "BBOX(" + this.map.getBounds().toBBoxString() + ")"
            };

        triggerEvent.apply(this, [evt, bboxJson]);
    };

    /**
     * [zoomLlvChangeEvt - PRIVATE event handler fn - when map zoom level change]
     * @param String evt - apex event name to trigger
     */
    var zoomLlvChangeEvt = function (evt) {
        var lvl = {
            "zoomLevel": this.map.getZoom()
        }
        triggerEvent.apply(this, [evt, lvl]);
    };
	/**
     * [saveElementEvt - PRIVATE event handler fn - when user clicked save]
     * @param String evt - apex event name to trigger
     */
    var saveElementEvt = function (evt) {
        var wkt;
        editableLayers.eachLayer(function (layer) {
            wkt = {
                "wkt": toWKT(layer)
            }
        });

        triggerEvent.apply(this, [evt, wkt]);
    };
    /**
     * [resizeMap        - PRIVATE event handler fn]
     * @param String evt - apex event name to trigger
     */
    var resizeMap = function (evt) {
        var o = {
            w: this.region.width(),
            h: this.region.height(),
        },
            timer,
            bounds = this.map.getBounds();

        // wait until html renders
        timer = setInterval(function () {
            if (o.w === this.region.width() &&
                o.h === this.region.height()) {

                if (this.container.hasClass("max-width") === false) {
                    this.container.addClass("max-width");
                } else {
                    this.container.removeClass("max-width");
                }

                this.map.invalidateSize();
                this.map.fitBounds(bounds);

                triggerEvent.apply(this, [evt]);
                clearInterval(timer);
            }
        }.bind(this), 100);
    };


    apex.plugins.mapbox.mapBoxMap = function (opts) {
        this.map = null;
        this.options = {};
        this.container = null;
        this.region = null;
        this.events = ["mapboxmap-change-bbox",
            "mapboxmap-change-zoomlevel",
            "mapboxmap-maximize-region",
            "mapboxmap-save-element"];
        this.jsName = "apex.plugins.mapBoxMap";
        this.apexname = "MAPBOXREGION";
        this.init = function () {

            if ($.isPlainObject(options)) {
                this.options = $.extend(true, {}, this.options, options, opts);
            } else {
                throw this.jsName || ": Invalid options passed.";
            }

            if (this.options.mapRegionContainer === null) {
                throw this.jsName || ": mapRegionContainer is required.";
            }

            this.container = $("#" + this.options.mapRegionContainer);

            if (this.container.length !== 1) {
                throw this.jsName || ": Invalid region selector.";
            }

            if (this.options.mapRegionId === null) {
                throw this.jsName || ": mapRegionContainer is required.";
            }

            this.region = $("#" + this.options.mapRegionId);

            if (this.region.length !== 1) {
                throw this.jsName || ": Invalid region selector.";
            }

            this.container.addClass("mapbox-map");
            this.container.get(0).id = "map";
            this.map = L.mapbox.map(this.container.get(0),
                'mapbox.streets',
                {
                    trackResize: true,
                    detectRetina: true
                });

            this.container.height(this.options.height);
            this.container.width(this.options.width);

            if (this.options.initalView.x &&
                this.options.initalView.y &&
                this.options.initalView.zoomLevel) {

                this.setView(
                    this.options.initalView.x,
                    this.options.initalView.y,
                    this.options.initalView.zoomLevel
                )
            }
        // WMS 
        // Add each wms layer using L.tileLayer.wms
//http://mapy.geoportal.gov.pl/wss/service/img/guest/ORTO/MapServer/WMSServer?service=wms&version=1.1.1&request=GetCapabilities
        var precipitation = L.tileLayer.wms('http://mapy.geoportal.gov.pl/wss/service/pub/guest/G2_bezrobocie_GUS_WMS/MapServer/WMSServer', {
            format: 'image/png',
            transparent: true,
            layers: '0'
        });
        var orto = L.tileLayer.wms('http://mapy.geoportal.gov.pl/wss/service/img/guest/ORTO/MapServer/WMSServer', {
            format: 'image/png',
            transparent: true,
            layers: 'Raster'
        });

        // WMS 
            this.map.on("move", bboxChangeEvt.bind(this, this.events[0]));
            this.map.on("zoomend", zoomLlvChangeEvt.bind(this, this.events[1]));
            this.map.on("draw:edited", saveElementEvt.bind(this, this.events[3]));
            this.region.on("click", 'span.js-maximizeButtonContainer', resizeMap.bind(this, this.events[2]));
            this.region.data("mapboxRegion", this);
            x.debug("apex.plugins.mapBoxMap : ", this);

            document.getElementById('precipitation').onclick = function () {
                var enable = this.className !== 'active';
                precipitation.setOpacity(enable ? 1 : 0);
                this.className = enable ? 'active' : '';
                return false;
            };
            document.getElementById('orto').onclick = function () {
                var enable = this.className !== 'active';
                orto.setOpacity(enable ? 1 : 0);
                this.className = enable ? 'active' : '';
                return false;
            };
            // leaflet draw addin

            this.map.addLayer(editableLayers);

            var MyCustomMarker = L.Icon.extend({
                options: {
                    shadowUrl: null,
                    iconAnchor: new L.Point(12, 12),
                    iconSize: new L.Point(24, 24)
                    , iconUrl: 'Leaflet_draw/Leaflet.draw-master/dist/images/marker-icon.png'
                }
            });

            var drawControl = new L.Control.Draw({
                position: 'topright', draw: {
                    polyline: {
                        shapeOptions: {
                            color: '#f357a1',
                            weight: 10
                        }
                    },
                    polygon: {
                        allowIntersection: false, // Restricts shapes to simple polygons
                        drawError: {
                            color: '#e1e100', // Color the shape will turn when intersects
                            message: '<strong>Oh snap!<strong> you can\'t draw that!' // Message that will show when intersect
                        },
                        shapeOptions: {
                            color: '#bada55'
                        }
                    },
                    circle: false, // Turns off this drawing tool
                    rectangle: {
                        shapeOptions: {
                            clickable: false
                        }
                    },
                    marker: {
                        icon: new MyCustomMarker()
                    }
                }, edit: { featureGroup: editableLayers, remove: false }
            });

            this.map.addControl(drawControl);
            // TODO: ADD THIS EVENTS TO  this.events ARRAY
            this.map.on(L.Draw.Event.CREATED, function (e) {
                editableLayers.addLayer(e.layer);
            });
            // SAVE Geometry
            this.map.on(L.Draw.Event.EDITED, function (e) {
                e.layers.eachLayer(function (layer) {
                    var wkt = toWKT(layer);
                });
            });

            this.map.on('draw:created', function (e) {
                var layer = e.layer;
                var wkt = toWKT(layer);
            });

            // leaflet draw addin
            return this;
            
        }

        return this.init();
    }
    apex.plugins.mapbox.mapBoxMap.prototype = {

        /**
         * [setView -  API method, zoom to spec. position]
         * @param   Number  x          x cord.
         * @param   Number  y          y cord.
         * @param   Number  zoomLevel zoomLevel
         */
        setView: function setView(x, y, zoomLevel) {
            xDebug.call(this, arguments.callee.name, arguments);
            return this.map
                .setView([x, y], zoomLevel);
        },

        /**
         * [zoomTo set/get zoomLevel]
         * @param   Number  zoomLevel
         * @return  Number  zoomLevel
         */
        zoomTo: function zoomTo(zoomLevel) {
            xDebug.call(this, arguments.callee.name, arguments);
            if (zoomLevel) {
                this.map.setZoom(zoomLevel);
            }

            return this.map.getZoom();
        },

        /**
         * [setBounds - zoom to spec. bounds]
         * @param L.bounds bbox     L.bounds - object
         * @param Number zoomLevel  zoomLevel - number
         */
        setBounds: function setBounds(bbox, zoomLevel) {
            xDebug.call(this, arguments.callee.name, arguments);
            this.map.fitBounds(bbox);
            if (this.map.zoomTo) {
                this.map.zoomTo(zoomLevel);
            }
            return this;
        },

        /**
         * [setGeoJSON - load geojson object on map]
         * @param Object  geoJson geoJson object
         * @param Boolean zoomTo  true/false to zoom on geometry bounds
         */
        setGeoJSON: function setGeoJSON(geoJson, zoomTo) {
            // xDebug.call(this, arguments.callee.name, arguments);
            var layers = this.map.featureLayer.setGeoJSON(geoJson);
            layers.eachLayer(function (layer) {
                layer.addTo(editableLayers);
            });
            if (zoomTo === true) {
                this.setBounds(this.map.featureLayer.getBounds());
            }
            return this;
        }

    };

})(apex.jQuery, apex);
