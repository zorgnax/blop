// PForm short for Post Form because I couldn't just call it Form

function PForm (args) {
    this.args = args;
    this.form = $(this.args.formId);
    this.mesg = this.form.find(".pform-mesg");
    var self = this;
    this.form.on("submit", function (event) {self.onSubmit(event)});
}

PForm.prototype.onSubmit = function (event) {
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

PForm.prototype.onDone = function (data, textStatus, jqXHR) {
    var self = this;
    this.form.find(":input[name]").each(function () {
        var errorDiv = self.form.find("." + this.name + "-error");
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
        this.mesg.text(data.mesg ? data.mesg : "Okay!");
        if (this.args.successUrl) {
            location.href = this.args.successUrl;
        }
        else if (this.args.onSuccess) {
            this.args.onSuccess(data);
        }
        else if (this.onSuccess) {
            this.onSuccess(data);
        }
        return;
    }
    this.mesg.text(data.mesg ? data.mesg : "");
}

PForm.prototype.onFail = function (jqXHR, textStatus, errorThrown) {
    this.mesg.text(errorThrown);
}

