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
    imageViewer.empty();
    var img = $("<img></img>");
    img.attr("src", thumbLink.attr("href"));
    imageViewer.append(img);
    imageViewer.show();
}

function createImageViewer () {
    imageViewer = $("<div class=\"image-viewer\"></div>");
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
        if (event.which == 27) {
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

