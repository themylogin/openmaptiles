CREATE OR REPLACE FUNCTION highway_is_link(highway TEXT) RETURNS BOOLEAN AS $$
    SELECT highway LIKE '%_link';
$$ LANGUAGE SQL IMMUTABLE STRICT;


-- etldoc: layer_transportation[shape=record fillcolor=lightpink, style="rounded,filled",
-- etldoc:     label="<sql> layer_transportation |<z4> z4 |<z5> z5 |<z6> z6 |<z7> z7 |<z8> z8 |<z9> z9 |<z10> z10 |<z11> z11 |<z12> z12|<z13> z13|<z14_> z14+" ] ;
CREATE OR REPLACE FUNCTION layer_transportation(bbox geometry, zoom_level int)
RETURNS TABLE(osm_id bigint, geometry geometry, class text, subclass text,
ramp int, oneway int, brunnel TEXT, service TEXT, layer INT, level INT,
indoor INT) AS $$
    SELECT
        osm_id, geometry,
        CASE
            WHEN highway IS NOT NULL OR public_transport IS NOT NULL THEN highway_class(highway, public_transport)
        END AS class,
        CASE
            WHEN (highway IS NOT NULL OR public_transport IS NOT NULL)
                AND highway_class(highway, public_transport) = 'path'
                THEN COALESCE(NULLIF(public_transport, ''), highway)
            ELSE NULL
        END AS subclass,
        -- All links are considered as ramps as well
        CASE WHEN highway_is_link(highway) OR highway = 'steps'
             THEN 1 ELSE is_ramp::int END AS ramp,
        is_oneway::int AS oneway,
        brunnel(is_bridge, is_tunnel, is_ford) AS brunnel,
        NULLIF(service, '') AS service,
        NULLIF(layer, 0) AS layer,
        "level",
        CASE WHEN indoor=TRUE THEN 1 ELSE NULL END as indoor
    FROM (
        -- etldoc: osm_highway_linestring       ->  layer_transportation:z12
        -- etldoc: osm_highway_linestring       ->  layer_transportation:z13
        -- etldoc: osm_highway_linestring       ->  layer_transportation:z14_
        SELECT
            osm_id, geometry,
            highway,
            public_transport, service_value(service) AS service,
            is_bridge, is_tunnel, is_ford, is_ramp, is_oneway,
            layer,
            CASE WHEN highway IN ('footway', 'steps') THEN "level"
                ELSE NULL::int
            END AS "level",
            CASE WHEN highway IN ('footway', 'steps') THEN indoor
                ELSE NULL::boolean
            END AS indoor,
            z_order
        FROM osm_highway_linestring
        WHERE highway IN ('cycleway', 'pedestrian')
    ) AS zoom_levels
    WHERE geometry && bbox
    ORDER BY z_order ASC;
$$ LANGUAGE SQL IMMUTABLE;
