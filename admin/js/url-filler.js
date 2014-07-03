function URLFiller (args) {
    this.args = args;
    this.fromInput = $(this.args.fromInputId);
    this.urlInput = $(this.args.urlInputId);
    var self = this;
    this.fromInput.on("keydown keyup", function () {self.fill()});
}

URLFiller.prototype.fill = function () {
    var url = this.fromInput.val();
    if (!url.length) {
        this.urlInput.val("");
        return;
    }
    url = url.toLowerCase();
    url = url.replace(/[\*\.\[\]\(\)\{\}\<\>\&"';:\?\/\^\%\|\$\#\@\!\,]/g, "");
    url = url.replace(/\s+/g, "-");
    if (this.args.prepend)
        url = this.args.prepend + url;
    this.urlInput.val(url);
}

