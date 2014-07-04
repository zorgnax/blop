function Comments (args) {
    this.args = args;
    this.initCommentForm(this.args.formId);
    var self = this;
    $(this.args.editableComments).each(function () {
        self.initEditCommentForm($(this));
    });
}

Comments.prototype.initCommentForm = function (formId) {
    var form = new PForm({
        formId: formId,
        processUrl: this.args.processUrl,
        onSuccess: function () {location.reload();}});
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
        data: {commentid: commentId}
    });
    ajax.done(function (data, textStatus, jqXHR) {
        if (data.error) {
            alert(data.mesg ? data.mesg : "Failed!");
        }
        else {
            var heading = div.find(".comment-heading");
            heading.find(".awaiting-moderation").remove();
            heading.find("a").remove();
            heading.append(" <span class='comment-deleted'>Deleted</span>");
        }
    });
    ajax.fail(function (jqXHR, textStatus, errorThrown) {
        alert(errorThrown);
    });
}

