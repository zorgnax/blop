var thumbLinks = $(".gallery a, .thumb a");
var thumbIndex;
var imageViewer;

thumbLinks.each(function (index) {
    $(this).on("click", function (event) {
        event.preventDefault();
        viewImage(index);
    });
});

function viewImage (index) {
    thumbIndex = index;
    var thumbLink = thumbLinks.eq(index);
    if (!imageViewer)
        createImageViewer();
    imageViewer.find(".image-viewer-main").empty();
    imageViewer.find(".image-viewer-info").empty();
    var img = $("<img></img>");
    img.attr("src", thumbLink.attr("href"));
    imageViewer.find(".image-viewer-main").append(img);
    if (index > 0) {
        var prev = $("<a href=\"#\">←</a>");
        prev.on("click", function (event) {
            event.preventDefault();
            event.stopPropagation();
            viewImage(index - 1);
        });
        imageViewer.find(".image-viewer-info").append(prev);
    }
    if (index < thumbLinks.length - 1) {
        var next = $("<a href=\"#\">→</a>");
        next.on("click", function (event) {
            event.preventDefault();
            event.stopPropagation();
            viewImage(index + 1);
        });
        if (prev) {
            imageViewer.find(".image-viewer-info").append("&nbsp;&nbsp;&nbsp;&nbsp;");
        }
        imageViewer.find(".image-viewer-info").append(next);
    }
    var span = $("<span></style>");
    span.css("float", "right");
    var close = $("<a href=\"#\">close</a>");
    close.on("click", function (event) {
        event.preventDefault();
        event.stopPropagation();
        imageViewer.hide();
    });
    span.append(close);
    imageViewer.find(".image-viewer-info").append(span);
    imageViewer.show();
}

function createImageViewer () {
    imageViewer = $("<div></div>");
    imageViewer.attr("class", "image-viewer");
    imageViewer.append("<table><tr><td></td></tr><tr><td></td></tr></table>");
    imageViewer.find("td").eq(0).attr("class", "image-viewer-main");
    imageViewer.find("td").eq(1).attr("class", "image-viewer-info");
    imageViewer.hide();
    imageViewer.appendTo("body");
    imageViewer.click(function (event) {
        event.preventDefault();
        imageViewer.hide();
    });
    $(document).keydown(function(event) {
        if ($(event.target).is('input, textarea'))
            return;
        if (!imageViewer || imageViewer.is(":hidden"))
            return;
        event.preventDefault();
        if (event.which == 27 || event.which == 81) {
            imageViewer.hide();
        }
        else if (event.which == 37) {
            if (thumbIndex > 0) {
                viewImage(thumbIndex - 1);
            }
        }
        else if (event.which == 39) {
            if (thumbIndex < thumbLinks.length - 1) {
                viewImage(thumbIndex + 1);
            }
        }
    });
}

