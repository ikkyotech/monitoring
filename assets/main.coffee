---
---

document.location.hash.substr(1).split("&").forEach (pair)->
    index = pair.indexOf("=")
    if index != -1
        key = pair.substr(0, index)
        value = decodeURIComponent(pair.substr(index+1))
        field = $("#" + key).first()
        field.val(value)
        field.parents("section").find("input[type=checkbox]").prop("checked", true);

OUT = $("#out")

update = ->
    variables = []
    $("section").each () ->
        if $("input[type=checkbox]", @)[0].checked
            $("form", @)[0].checkValidity()
            $(".args input", @).each () ->
                if @.type == "checkbox"
                    console.log @.attributes.default
                    if @.checked.toString() != $(@).attr("default")
                        variables.push
                            name: @.id
                            value: @.checked
                else if @.value != "" || !@.hasAttribute("placeholder")
                    variables.push
                        name: @.id
                        value: @.value
                return
        return

    variableString = " "
    hashString = ""
    variables.forEach (variable)->
        value = variable.value
        if /[\"\'\\ ]/.test(value)
            value = '"' + variable.value.replace(/\\/g, "\\\\").replace(/\"/g, '\\\"') + '\"'
        variableString += "#{variable.name}=#{value} "
        hashString += "#{variable.name}=" + encodeURIComponent(variable.value)+"&"

    document.location.hash = hashString
    OUT.val("curl -sL " + document.location.origin + document.location.pathname + "install.sh | " + variableString + "bash");
    return

$("input").change(update).on "input", update
update()