// Set default options
JSONEditor.defaults.options.theme = 'bootstrap3';
JSONEditor.defaults.options.disable_edit_json = true;
JSONEditor.defaults.options.disable_properties = true;

fetch('/schema.json').then(res => res.json()).then(json => {
  console.log(json);
  var editor = new JSONEditor(document.getElementById("editor"), {
    schema: json
  });
  var button = document.getElementById('submit')
  button.onclick = () => {
    console.log('clicked!')
    console.log(editor.getValue())
    fetch('/update', {
      method: 'POST',
      body: JSON.stringify(editor.getValue()),
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
});
