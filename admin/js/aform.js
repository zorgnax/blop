function AForm (args) {
    this.args = args;
    this.form = $(this.args.formId);
    this.mesg = $(this.args.formId + "-mesg");
    var self = this;
    this.form.on("submit", function (event) {self.onSubmit(event)});
}

AForm.prototype.onSubmit = function (event) {
    event.preventDefault();
    this.mesg.text("Processing...");
    var self = this;
    var ajax = $.ajax({
        url: this.args.processUrl,
        type: "POST",
        data: this.form.serialize()
    });
    ajax.done(function () {self.onDone.apply(self, arguments)});
    ajax.fail(function () {self.onFail.apply(self, arguments)});
}

AForm.prototype.onDone = function (data, textStatus, jqXHR) {
    this.form.find(":input[name]").each(function () {
        if (this.name + "Error" in data) {
            $("#" + this.name + "-error").text(data[this.name + "Error"]);
            $(this).css("backgroundColor", "lightpink");
        }
        else {
            $("#" + this.name + "-error").text("");
            $(this).css("backgroundColor", "");
        }
    });
    if (!data.error) {
        this.mesg.text(data.mesg ? data.mesg : "Okay!");
        if (this.args.successUrl) {
            location.href = this.args.successUrl;
        }
        else if (this.onSuccess) {
            this.onSuccess(data);
        }
        return;
    }
    this.mesg.text(data.mesg ? data.mesg : "");
}

AForm.prototype.onFail = function (jqXHR, textStatus, errorThrown) {
    this.mesg.text(errorThrown);
}

