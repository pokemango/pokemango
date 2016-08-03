require('coffee-script/register');
const express = require('express');
const bodyParser = require('body-parser');
const PokemonGoMITM = require('./lib/pokemon-go-mitm');
const modifiers = require('./lib/modifiers');

const app = require('express')();
const server = require('http').Server(app);
const io = require('socket.io')(server);

const mitm = new PokemonGoMITM({ port: 8081 })

app.use(express.static('app'));
app.use(bodyParser.json());
app.use(bodyParser.text());
app.set('view engine', 'pug');
app.set('views', './app/views');


server.listen(3000);


const Tail = require('tail').Tail;
const tail = new Tail('test.log');

function updateHandler(modRequests) {
  Object.keys(modRequests).forEach(modifierId => {
    console.log("Applying #{modifierId}");
    modifiers[modifierId].apply(mitm, options);
  });
}

app.get('/', function (req, res) {
  res.render('index');
});
app.get('/tail', function (req, res) {
  res.render('tail');
});


app.get('/schema.json', (req, res) => {
  res.send(modifiers.schema)
});

app.post('/update', (req, res) => {
  mitm.close();
  mitm = new PokemonGoMITM({ port: 8081 })
  updateHandler(req.body);
});

io.on('connection', function (socket) {
  tail.on('line', function(data) {
    socket.emit('tail', { data: data });
    console.log(data)
  });
});

tail.on("error", function(error) {
  console.log('ERROR: ', error);
});
