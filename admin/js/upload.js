function Upload (args) {
    this.args = args;
    var id = this.args.divId;
    this.div = $(id);
    this.mesg = $(id + "-mesg");
    this.files = $(id + " input[type=file]");
    this.filesList = $(id + " table.files-list");
    this.abortLink = $(id + " .abort");
    this.xhr = null;
    var self = this;

    this.setGalleryInserts();
    
    this.filesList.find("tr").each(function () {
        self.setFileRow($(this))
    });
    
    this.abortLink.on("click", function (event) {
        event.preventDefault();
        self.abort();
    });
    
    this.files.on("change", function () {
        self.uploadFileChain(0);
    });
}

Upload.prototype.abort = function () {
    this.xhr.abort();
    this.end("");
}

Upload.prototype.uploadFileChain = function (i) {
    if (!i) {
        this.start();
    }
    var file = this.files[0].files[i];
    if (!file) {
        this.end();
        return;
    }
    this.mesg.text("Uploading " + file.name + ".");
    var fd = new FormData();
    fd.append("file", file);
    if (this.extraParams) {
        var extra = this.extraParams();
        $.each(extra, function (key, value) {
            fd.append(key, value);
        });
    }
    this.xhr = new XMLHttpRequest();
    var self = this;
    this.xhr.upload.onprogress = function (event) {
        self.progress(event, file, i);
    };
    this.xhr.onload = function (event) {
        self.load(event, file, i);
    }
    this.xhr.open("POST", this.args.processUrl);
    this.xhr.send(fd);
}

Upload.prototype.progress = function (event, file, i) {
    if (!event.lengthComputable)
        return;
    var n = this.files[0].files.length;
    var complete = event.loaded / event.total * 100;
    complete = complete.toFixed(2);
    var loaded = this.humanReadable(event.loaded);
    var total = this.humanReadable(event.total);
    this.mesg.text("Uploading " + (i + 1) + "/" + n + " " + file.name + " " + loaded + "/" + total + " or " + complete + "%");
}

Upload.prototype.load = function (event, file, i) {
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
        this.mesg.text(data.mesg ? data.mesg : "");
        return;
    }
    this.div.find(".gallery-inserts").show();
    if (this.onSuccess)
        this.onSuccess(data);
    this.addFileToList(data);
    this.mesg.text("");
    this.uploadFileChain(i + 1);
}

Upload.prototype.addFileToList = function (data) {
    var tr = $("<tr><td><a href=\"" + data.fullurl + "\" target=\"_blank\">" +
             data.name + "</a></td><td class=\"muted\">" + data.size +
             "</td></tr>");
    var inserts = $("<td class=\"file-inserts\"></td>").appendTo(tr);
    var select = $("<select></select>").appendTo(inserts);
    select.append("<option value=\"\"></option>");
    if (data.name.match(/\.(jpe?g|png|gif)$/i)) {
        select.append("<option value=\"small-thumb\">Small Thumb</option>");
        select.append("<option value=\"medium-thumb\">Medium Thumb</option>");
        select.append("<option value=\"large-thumb\">Large Thumb</option>");
        select.append("<option value=\"image\">Image</option> ");
    }
    select.append("<option value=\"link\">link</option>");
    tr.append("<td class=\"file-actions\"><a href=\"#\" class=\"file-delete\">delete</a></td>");
    tr.data("name", data.name);
    tr.data("url", data.url);
    this.setFileRow(tr);
    tr.appendTo(this.filesList);
    this.filesList.show();
}

Upload.prototype.start = function () {
    this.files[0].disabled = true;
    this.abortLink.show();
}

Upload.prototype.end = function (text) {
    if (text != null)
        this.mesg.text(text);
    this.files[0].disabled = false;
    this.files.val("");
    this.abortLink.hide();
}

Upload.prototype.setGalleryInserts = function () {
    var editor = this.args.editor;
    if (!editor)
        return;
    var select = this.div.find(".gallery-inserts select");
    select.on("change", function () {
        var val = select.val();
        select.val("");
        if (val == "small-gallery") {
            editor.insert("[gallery size=\"small\" /]");
        }
        else if (val == "medium-gallery") {
            editor.insert("[gallery size=\"medium\" /]");
        }
        else if (val == "large-gallery") {
            editor.insert("[gallery size=\"large\" /]");
        }
        else if (val == "listing") {
            editor.insert("[listing /]");
        }
    });
}

Upload.prototype.delete = function (name, tr) {
    this.mesg.text("Processing...");
    var self = this;
    var data = {name: name};
    if (this.extraParams) {
        var extra = this.extraParams();
        $.each(extra, function (key, value) {
            data[key] = value;
        });
    }
    var ajax = $.ajax({
        url: this.args.deleteUrl,
        type: "POST",
        data: data
    });
    ajax.done(function (data, textStatus, jqXHR) {
        if (!data.error) {
            self.mesg.text(data.mesg ? data.mesg : "Okay!");
            tr.remove();
            return;
        }
        self.mesg.text(data.mesg ? data.mesg : "");
    });
    ajax.fail(function (jqXHR, textStatus, errorThrown) {
        self.mesg.text(errorThrown);
    });
}

Upload.prototype.setFileRow = function (tr) {
    var self = this;
    var deleteLink = tr.find("a.file-delete");
    deleteLink.on("click", function (event) {
        event.preventDefault();
        self.delete(tr.data("name"), tr);
    });
    var editor = this.args.editor;
    if (!editor)
        return;
    var select = tr.find(".file-inserts select");
    select.on("change", function () {
        var val = select.val();
        select.val("");
        if (val == "small-thumb") {
            editor.insert("[thumb \"" + tr.data("name") + "\" size=\"small\" /]");
        }
        else if (val == "medium-thumb") {
            editor.insert("[thumb \"" + tr.data("name") + "\" size=\"medium\" /]");
        }
        else if (val == "large-thumb") {
            editor.insert("[thumb \"" + tr.data("name") + "\" size=\"large\" /]");
        }
        else if (val == "image") {
            editor.insert("[image \"" + tr.data("name") + "\" /]");
        }
        else if (val == "link") {
            editor.insert("[link \"" + tr.data("url") + "\"]" + tr.data("name") + "[/link]");
        }
    });
}

Upload.prototype.humanReadable = function (size) {
    var power = ["B", "K", "M", "G", "T", "P", "E", "Z", "Y"];
    for (var i = 0; i < power.length; i++) {
        if (size < 1024)
            break;
        size /= 1024;
    }
    return size.toFixed(2) + power[i];
}

