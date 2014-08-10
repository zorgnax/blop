var gallery = new Gallery({thumbLinks: ".gallery a, .thumb a"});

function Gallery (args) {
    this.args = args;
    this.thumbLinks = $(this.args.thumbLinks);
    this.thumbIndex = 0;
    var self = this;
    this.thumbLinks.each(function (index) {
        $(this).on("click", function (event) {
            event.preventDefault();
            self.viewImage(index);
        });
    });
}

Gallery.prototype.viewImage = function (index) {
    this.thumbIndex = index;
    var thumbLink = this.thumbLinks.eq(index);
    if (!this.imageViewer)
        this.createImageViewer();
    this.imageViewer.find(".image-viewer-main").empty();
    var img = $("<img></img>");
    img.attr("src", thumbLink.attr("href"));
    this.imageViewer.find(".image-viewer-main").append(img);
    this.imageViewer.show();
}

Gallery.prototype.createImageViewer = function () {
    this.imageViewer = $("<div></div>");
    this.imageViewer.attr("class", "image-viewer");
    this.imageViewer.append("<div class=\"image-viewer-main\"></div>");
    this.imageViewer.append("<div class=\"image-viewer-info\"></div>");
    var info = this.imageViewer.find(".image-viewer-info");
    var self = this;

    var prev = $("<a href=\"#\">prev</a>");
    prev.on("click", function (event) {
        event.preventDefault();
        event.stopPropagation();
        self.prev();
    });
    info.append(prev);
    info.append(" ");

    var next = $("<a href=\"#\">next</a>");
    next.on("click", function (event) {
        event.preventDefault();
        event.stopPropagation();
        self.next();
    });
    info.append(next);
    info.append(" ");

    var close = $("<a href=\"#\">close</a>");
    close.on("click", function (event) {
        event.preventDefault();
        event.stopPropagation();
        self.close();
    });
    info.append(close);
    this.imageViewer.hide();
    this.imageViewer.appendTo("body");
    this.imageViewer.click(function (event) {
        event.preventDefault();
        self.imageViewer.hide();
    });
    $(document).keydown(function(event) {
        if ($(event.target).is('input, textarea'))
            return;
        if (!self.imageViewer || self.imageViewer.is(":hidden"))
            return;
        event.preventDefault();
        if (event.which == 27 || event.which == 81) {
            self.imageViewer.hide();
        }
        else if (event.which == 37) {
            self.prev();
        }
        else if (event.which == 39) {
            self.next();
        }
    });
}

Gallery.prototype.prev = function () {
    if (this.thumbIndex > 0) {
        this.viewImage(this.thumbIndex - 1);
    }
}

Gallery.prototype.next = function () {
    if (this.thumbIndex < this.thumbLinks.length - 1) {
        this.viewImage(this.thumbIndex + 1);
    }
}

Gallery.prototype.close = function () {
    this.imageViewer.hide();
}

