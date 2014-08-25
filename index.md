---
---

# Ikkyotech Server Monitoring

Hello dear fellow, this is your friendly helper to get a install
script for the server monitoring we all crave for. Just select
the features you want your server to have and then copy the install
script and run it on your Ubuntu or Redhat-based server.

Cheers!

<div>

<style type="text/css">
.args {
    display: none;
}
section > input:checked + .info > .args  {
    display: block;
}
input:invalid {
    background: #fdd;
}
#out {
    width: 800px;
    height: 200px;
}
p.description:before {
    content: "(";
}
p.description:after {
    content: ")";
}
p.description {
    color: #999;
    margin: 0;
}
p.description a {
    text-decoration: none;
    color: #333;
    border-bottom: 4px solid #DDD;
}
.info {
    display: inline;
}
</style>

{% for section in site.data.fields.sections %}
    <section>
        <input type="checkbox">
        <div class="info">
            <label>{{ section.name }}</label>
            <form name="{{ section.name }}" class="args">
                {% if section.desc %}
                <p class="description">
                    {{ section.desc }}
                </p>
                {% endif %}
                <ul>
                {% for arg in section.args %}
                    <li>
                        <label>{{ arg.name }}</label>
                        {% if arg.type == "boolean" %}
                        <input id="{{ arg.name }}" type="checkbox" default="{{ arg.default }}" {% if arg.default == "true" %}checked{% endif %}>
                        {% else %}
                        <input id="{{ arg.name }}" type="text" data-type="{{ arg.type | default:'text' }}" {% if arg.default || arg.default == empty %}placeholder="{{ arg.default }}" {% else %}required{% endif %}>
                        {% endif %}
                        {% if arg.desc %}
                        <p class="description">
                            {{ arg.desc }}
                            {% if arg.type == "pattern" %}
                                - <a href="http://docs.fluentd.org/articles/config-file#match-pattern-how-you-control-the-event-flow-inside-fluentd" target="_blank">Pattern?</a>
                            {% endif %}
                        </p>
                        {% endif %}
                    </li>
                {% endfor %}
                </ul>
            </form>
        </div>
    </section>
{% endfor %}
    
    <textarea id="out"></textarea>
</div>

<script type="text/javascript" src="//code.jquery.com/jquery-2.1.1.min.js"></script>
<script type="text/javascript" src="assets/main.js"></script>

### Notes:

Be aware that [the order](http://docs.fluentd.org/articles/config-file#match-order){:target="_blank"} that FluentD uses to match patterns is **important** and based on [how it resolves includes](http://docs.fluentd.org/articles/config-file#3-re-use-your-config-the-ldquoincluderdquo-directive){:target="_blank"}.