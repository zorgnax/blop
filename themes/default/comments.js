function Comments (args) {
    this.args = args;
    this.initCommentForm($(this.args.formId));
    var self = this;
    $(this.args.deletableComments).each(function () {
        var div = $(this);
        div.find(".delete-comment").on("click", function (event) {
            event.preventDefault();
            self.delete(div);
        });
    });
    $(this.args.editableComments).each(function () {
        self.initEditCommentForm($(this));
    });
}

Comments.prototype.initCommentForm = function (form) {
    var self = this;
    form.on("submit", function (event) {
        event.preventDefault();
        self.submit(form)
    });
}

Comments.prototype.initEditCommentForm = function (div) {
    this.initCommentForm(div.find(".edit-comment-form form"));
    var self = this;
    div.find(".edit-comment").on("click", function (event) {
        event.preventDefault();
        self.edit(div);
    });
    div.find(".delete-comment").on("click", function (event) {
        event.preventDefault();
        self.delete(div);
    });
}

Comments.prototype.edit = function (div) {
    var formDiv = div.find(".edit-comment-form");
    var content = div.find(".comment-content");
    var ta = formDiv.find("textarea")[0];
    if (formDiv.is(":hidden")) {
        formDiv.show();
        content.hide();
        div.addClass("editing-comment");
        ta.focus();
        ta.selectionStart = ta.selectionEnd = ta.value.length;
    }
    else {
        formDiv.hide();
        content.show();
        div.removeClass("editing-comment");
    }
}

Comments.prototype.delete = function (div) {
    var commentId = div.data("commentid");
    var ajax = $.ajax({
        url: this.args.deleteUrl,
        type: "POST",
        data: {commentid: commentId, csrf: this.args.csrf}
    });
    ajax.done(function (data, textStatus, jqXHR) {
        if (data.error) {
            alert(data.mesg ? data.mesg : "Failed!");
        }
        else {
            var heading = div.find(".comment-heading");
            heading.find(".comment-awaiting-moderation").remove();
            heading.find("a").remove();
            heading.append(" <span class='comment-deleted'>Deleted</span>");
        }
    });
    ajax.fail(function (jqXHR, textStatus, errorThrown) {
        alert(errorThrown);
    });
}

Comments.prototype.submit = function (form) {
    form.find(".comment-main-mesg").text("Processing...");
    var self = this;
    var ajax = $.ajax({
        url: this.args.processUrl,
        type: "POST",
        data: form.serialize()
    });
    ajax.done(function (data, textStatus, jqXHR) {
        self.done(form, data, textStatus, jqXHR);
    });
    ajax.fail(function (jqXHR, textStatus, errorThrown) {
        self.fail(form, jqXHR, textStatus, errorThrown);
    });
}

Comments.prototype.done = function (form, data, textStatus, jqXHR) {
    var self = this;
    form.find(":input[name]").each(function () {
        var errorDiv = form.find("." + this.name + "-error");
        if (this.name + "Error" in data) {
            errorDiv.text(data[this.name + "Error"]);
            $(this).css("backgroundColor", "lightpink");
        }
        else {
            errorDiv.text("");
            $(this).css("backgroundColor", "");
        }
    });
    if (!data.error) {
        form.find(".comment-main-mesg").text(data.mesg ? data.mesg : "Okay!");
        location.reload();
        return;
    }
    form.find(".comment-main-mesg").text(data.mesg ? data.mesg : "");
}

Comments.prototype.fail = function (form, jqXHR, textStatus, errorThrown) {
    form.find(".comment-main-mesg").text(errorThrown);
}

