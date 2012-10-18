var min_lat, min_long, max_lat, max_long, centre_lat, centre_long, map;
var positions = [], markers = [];
var base_url = "http://londonbookshops.org/";
var icons = {};

var gicon = L.Icon.extend( {
    shadowUrl: null,
    iconSize: new L.Point( 32, 32 ),
    iconAnchor: new L.Point( 15, 32 ),
    popupAnchor: new L.Point( 0, -40 )
} );
var icon_base_url = 'http://maps.google.com/mapfiles/ms/micons/';

icons.open = new gicon( icon_base_url + 'green-dot.png' );
icons.closed = new gicon( icon_base_url + 'red-dot.png' );

$(
  function() {
    $('#map_canvas').height( $(window).height() - $('#banner').height() );
    var map_centre = new L.LatLng( centre_lat, centre_long );
    map = new L.Map( 'map_canvas', { center: map_centre } );

    var tile_layer;
    var mq_url = 'http://{s}.mqcdn.com/tiles/1.0.0/osm/{z}/{x}/{y}.png';
    var subdomains = [ 'otile1', 'otile2', 'otile3', 'otile4' ];
    var attrib = 'Data, imagery and map information provided by <a href="http://open.mapquest.co.uk" target="_blank">MapQuest</a>, <a href="http://www.openstreetmap.org/" target="_blank">OpenStreetMap</a> and contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/" target="_blank">CC-BY-SA</a>';

    tile_layer = new L.TileLayer( mq_url, { maxZoom: 18, attribution: attrib, subdomains: subdomains } );

    if ( min_lat && ( min_lat != max_lat ) ) {
      var bounds = new L.LatLngBounds( new L.LatLng( min_lat, min_long ),
                                       new L.LatLng( max_lat, max_long ) );
      map.fitBounds( bounds );
    } else {
      map.setView( map_centre, 13 );
    }

    map.addLayer( tile_layer );

    add_markers();
  }
);

function add_marker( i, shop ) {
  var content, icon, marker, position;

  if ( shop.not_on_map ) {
    return;
  }

  position = new L.LatLng( shop.lat, shop.long );

  if ( shop.open ) {
    icon = icons.open;
  } else {
    icon = icons.closed;
  }

  marker = new L.Marker( position, { icon: icon } );
  map.addLayer( marker );

  content = '<a href="' + base_url + 'shops/' + shop.id + '.html">' +
            shop.name + '</a>';
  if ( !shop.open ) {
    content = content + ' (closed)';
  }
  content = content + '<br>' + shop.address;

  marker.bindPopup( content );

  markers[ i ] = marker;
  positions[ i ] = position;
}

function show_marker( i ) {
  markers[ i ].openPopup();
  map.panTo( positions[ i ] );
  return false;
}

