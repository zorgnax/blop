function Component (args) {
    this.args = args;
    this.div = $(this.args.divId);
    this.mesg = this.div.find(".component-mesg");
    this.abortLink = this.div.find(".abort");
    this.deleteLink = this.div.find(".delete-component");
    this.fileInput = this.div.find("input[type=file]");
    this.xhr = null;
    var self = this;
    this.abortLink.on("click", function (event) {
        event.preventDefault();
        self.abort();
    });
    this.deleteLink.on("click", function (event) {
        event.preventDefault();
        self.delete();
    });
    this.fileInput.on("change", function () {
        self.uploadFile();
    });
}

Component.prototype.abort = function () {
    this.xhr.abort();
    this.end("");
}

Component.prototype.end = function (text) {
    if (text != null)
        this.mesg.text(text);
    this.fileInput[0].disabled = false;
    this.abortLink.hide();
}

Component.prototype.uploadFile = function () {
    this.fileInput[0].disabled = true;
    this.abortLink.show();
    var file = this.fileInput[0].files[0];
    if (!file) {
        this.end();
        return;
    }
    this.mesg.text("Uploading " + file.name + ".");
    var fd = new FormData();
    fd.append("file", file);
    fd.append("component", this.args.component);
    this.xhr = new XMLHttpRequest();
    var self = this;
    this.xhr.upload.onprogress = function (event) {
        self.progress(event, file);
    };
    this.xhr.onload = function (event) {
        self.load(event, file);
    }
    this.xhr.open("POST", this.args.processUrl);
    this.xhr.send(fd);
}

Component.prototype.progress = function (event, file) {
    if (!event.lengthComputable)
        return;
    var complete = event.loaded / event.total * 100;
    complete = complete.toFixed(2);
    var loaded = this.humanReadable(event.loaded);
    var total = this.humanReadable(event.total);
    this.mesg.text("Uploading " + file.name + " " + loaded + "/" + total + " or " + complete + "%");
}

Component.prototype.load = function (event, file) {
    if (event.target.status != 200) {
        this.end(event.target.status + " " + event.target.statusText);
        return;
    }
    try {
        var data = JSON.parse(event.target.response);
    }
    catch (error) {
        this.end(error.message);
        return;
    }
    if (data.error) {
        this.end(data.mesg ? data.mesg : "");
        return;
    }
    this.div.find(".component-image").empty();
    if (this.args.link) {
        var link = $("<a></a>");
        link.attr("href", data.fullurl);
        link.attr("target", "_blank");
        link.html("link");
        this.div.find(".component-image").append(link);
    }
    else {
        var img = $("<img></img>");
        img.attr("src", data.fullurl);
        this.div.find(".component-image").append(img);
    }
    this.div.find(".component-view").show();
    this.end("");
}

Component.prototype.humanReadable = function (size) {
    var power = ["B", "K", "M", "G", "T", "P", "E", "Z", "Y"];
    for (var i = 0; i < power.length; i++) {
        if (size < 1024)
            break;
        size /= 1024;
    }
    return size.toFixed(2) + power[i];
}

Component.prototype.delete = function () {
    this.mesg.text("Processing...");
    var self = this;
    var data = {component: this.args.component};
    var ajax = $.ajax({url: this.args.deleteUrl, type: "POST", data: data});
    ajax.done(function (data, textStatus, jqXHR) {
        if (!data.error) {
            self.mesg.text(data.mesg ? data.mesg : "Okay!");
            self.div.find(".component-view").hide();
            return;
        }
        this.div.find(".component-view").hide();
        self.mesg.text(data.mesg ? data.mesg : "");
    });
    ajax.fail(function (jqXHR, textStatus, errorThrown) {
        self.mesg.text(errorThrown);
    });
}

