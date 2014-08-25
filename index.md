---
---

<div>

<style type="text/css">
.args {
    display: none;
}
section > input:checked + .info > .args  {
    display: block;
}
</style>

{% for section in site.data.fields.sections %}
    <section>
        <input type="checkbox">
        <div class="info">
            <label>{{ section.name }}</label>
            <ul class="args">
            {% for arg in section.args %}
                <li>
                    <label for="">{{ arg.name }}</label>
                    <input id="{{ arg.name }}" type="text">
                </li>
            {% endfor %}
            </ul>
        </div>
    </section>
{% endfor %}
    
</div>