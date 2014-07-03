function Editor (args) {
    this.args = args;
    var id = this.args.divId;
    this.div = $(id);
    this.ta = this.div.find("textarea")[0];
    if (!"selectionStart" in this.ta) {
        throw "Cannot insert text into textarea.";
    }
    this.addButton(id + " .editor-bold", this.bold);
    this.addButton(id + " .editor-italics", this.italics);
    this.addButton(id + " .editor-link", this.link);
    this.addButton(id + " .editor-quote", this.quote);
    this.addButton(id + " .editor-indent", this.indent);
    this.addButton(id + " .editor-outdent", this.outdent);
    this.addButton(id + " .editor-image", this.image);
    this.addButton(id + " .editor-ul", this.ul);
    this.addButton(id + " .editor-ol", this.ol);
    this.addButton(id + " .editor-header", this.header);
    this.addButton(id + " .editor-hr", this.hr);
}

Editor.prototype.addButton = function (elem, textAction) {
    var self = this;
    $(elem).on("click", function (event) {
        event.preventDefault();
        textAction.call(self);
    });
}

Editor.prototype.insert = function (textAction) {
    var sel = this.sel();
    this.ta.value = sel.pre + textAction + sel.post;
    this.ta.selectionStart = sel.start;
    this.ta.selectionEnd = sel.start + textAction.length;
    this.ta.focus();
    this.ta.scrollTop = sel.top;
}

Editor.prototype.sel = function () {
    var sel = {};
    sel.start = this.ta.selectionStart;
    sel.end = this.ta.selectionEnd;
    sel.top = this.ta.scrollTop;
    sel.pre = this.ta.value.substr(0, sel.start);
    sel.text = this.ta.value.substr(sel.start, sel.end - sel.start);
    sel.post = this.ta.value.substr(sel.end, this.ta.value.length);
    return sel;
}

Editor.prototype.lineSel = function () {
    var sel = {};
    sel.start = 0;
    for (var i = this.ta.selectionStart; i >= 0; i--) {
        if (this.ta.value.substr(i, 1) == "\n") {
            sel.start = i + 1;
            break;
        }
    }
    sel.end = this.ta.value.length;
    for (var i = this.ta.selectionEnd; i < this.ta.value.length; i++) {
        if (this.ta.value.substr(i, 1) == "\n") {
            sel.end = i;
            break;
        }
    }
    sel.top = this.ta.scrollTop;
    sel.pre = this.ta.value.substr(0, sel.start);
    sel.text = this.ta.value.substr(sel.start, sel.end - sel.start);
    sel.post = this.ta.value.substr(sel.end, this.ta.value.length);
    return sel;
}

Editor.prototype.bold = function () {
    var sel = this.sel();
    if (sel.pre.match(/\*\*$/) && sel.post.match(/^\*\*/)) {
        this.ta.value = sel.pre.substr(0, sel.pre.length - 2) + sel.text +
                   sel.post.substr(2, sel.post.length);
        this.ta.selectionStart = sel.start - 2;
        this.ta.selectionEnd = sel.start - 2 + sel.text.length;
    }
    else {
        var text = sel.text ? sel.text : "bold text";
        this.ta.value = sel.pre + "**" + text + "**" + sel.post;
        this.ta.selectionStart = sel.start + 2;
        this.ta.selectionEnd = sel.start + text.length + 2;
    }
}

Editor.prototype.italics = function () {
    var sel = this.sel();
    if (sel.pre.match(/\*$/) && sel.post.match(/^\*/)) {
        this.ta.value = sel.pre.substr(0, sel.pre.length - 1) + sel.text +
                   sel.post.substr(1, sel.post.length);
        this.ta.selectionStart = sel.start - 1;
        this.ta.selectionEnd = sel.start + sel.text.length - 1;
    }
    else {
        var text = sel.text ? sel.text : "italics text";
        this.ta.value = sel.pre + "*" + text + "*" + sel.post;
        this.ta.selectionStart = sel.start + 1;
        this.ta.selectionEnd = sel.start + text.length + 1;
    }
}

Editor.prototype.link = function () {
    var sel = this.sel();
    var prematch = sel.pre.match(/<a\s+[^>]*>$/);
    var postmatch = sel.post.match(/^<\/a>/);
    if (prematch && postmatch) {
        this.ta.value =
            sel.pre.substr(0, sel.pre.length - prematch[0].length) +
            sel.text + sel.post.substr(postmatch[0].length, sel.post.length);
        this.ta.selectionStart = sel.start - prematch[0].length;
        this.ta.selectionEnd = sel.start - prematch[0].length + sel.text.length;
    }
    else {
        var text = sel.text ? sel.text : "link text";
        var url = prompt("Insert Hyperlink", "http://example.com");
        if (!url)
            return;
        var pretext = "<a href=\"" + url + "\">";
        var posttext = "</a>";
        this.ta.value = sel.pre + pretext + text + posttext + sel.post;
        this.ta.selectionStart = sel.start + pretext.length;
        this.ta.selectionEnd = sel.start + pretext.length + text.length;
    }
}

Editor.prototype.quote = function () {
    var sel = this.lineSel();
    var text = sel.text ? sel.text : "quote text";
    text = text.replace(/^>/gm, ">>");
    text = text.replace(/^([^>])/gm, "> $1");
    this.ta.value = sel.pre + text + sel.post;
    this.ta.selectionStart = sel.start;
    this.ta.selectionEnd = sel.start + text.length;
}

Editor.prototype.indent = function () {
    var sel = this.lineSel();
    var text = sel.text ? sel.text : "indent text";
    text = text.replace(/^/gm, "    ");
    this.ta.value = sel.pre + text + sel.post;
    this.ta.selectionStart = sel.start;
    this.ta.selectionEnd = sel.start + text.length;
}

Editor.prototype.outdent = function () {
    var sel = this.lineSel();
    var text = sel.text ? sel.text : "outdent text";
    text = text.replace(/^    /gm, "");
    this.ta.value = sel.pre + text + sel.post;
    this.ta.selectionStart = sel.start;
    this.ta.selectionEnd = sel.start + text.length;
}

Editor.prototype.image = function () {
    var sel = this.sel();
    var text = "<img src=\"/image.jpg\"></img>";
    this.ta.value = sel.pre + text + sel.post;
    this.ta.selectionStart = sel.start + 10;
    this.ta.selectionEnd = sel.start + 20;
}

Editor.prototype.ul = function () {
    var sel = this.lineSel();
    var text = sel.text ? sel.text : "list item";
    if (text.match(/^\s*-\s+/)) {
        text = text.replace(/^\s*-\s+/, "");
        text = text.replace(/\n\s+/g, "\n");
    }
    else {
        text = " - " + text;
        text = text.replace(/\n/g, "\n   ");
    }
    this.ta.value = sel.pre + text + sel.post;
    this.ta.selectionStart = sel.start;
    this.ta.selectionEnd = sel.start + text.length;
}

Editor.prototype.ol = function () {
    var sel = this.lineSel();
    var text = sel.text ? sel.text : "list item";
    if (text.match(/^\s*\d+\.\s+/)) {
        text = text.replace(/^\s*\d\.\s+/, "");
        text = text.replace(/\n\s+/g, "\n");
    }
    else {
        text = " 1. " + text;
        text = text.replace(/\n/g, "\n    ");
    }
    this.ta.value = sel.pre + text + sel.post;
    this.ta.selectionStart = sel.start;
    this.ta.selectionEnd = sel.start + text.length;
}

Editor.prototype.header = function () {
    var sel = this.sel();
    var prematch = sel.pre.match(/\n$/);
    var postmatch = sel.post.match(/^\n=+\n/);
    if (prematch && postmatch) {
        this.ta.value = sel.pre.substr(0, sel.pre.length - prematch[0].length) +
                   sel.text +
                   sel.post.substr(postmatch[0].length, sel.post.length);
        this.ta.selectionStart = sel.start - prematch[0].length;
        this.ta.selectionEnd = sel.start - prematch[0].length + sel.text.length;
    }
    else {
        var text = sel.text ? sel.text : "header text";
        var underline = Array(text.length + 1).join("=");
        this.ta.value = sel.pre + "\n" + text + "\n" + underline + "\n\n" + sel.post;
        this.ta.selectionStart = sel.start + 1;
        this.ta.selectionEnd = sel.start + text.length + 1;
    }
}

Editor.prototype.hr = function () {
    var sel = this.sel();
    var text = "\n---\n\n";
    this.ta.value = sel.pre + text + sel.post;
    this.ta.selectionStart = sel.start + text.length;
    this.ta.selectionEnd = sel.start + text.length;
}

