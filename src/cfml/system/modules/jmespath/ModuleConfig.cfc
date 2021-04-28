component {

    this.name = 'JMESPath';
    this.title = 'JMESPath';
    this.author = 'Scott Steinbeck';
    this.webURL = 'https://github.com/scottsteinbeck/jmespath';
    this.description = 'An JMESPath port for Coldfusion. A query language for JSON.';
    this.version = '2.4.0';
    this.autoMapModels = true;

    function configure() {
        binder.map('jmespath').to('#moduleMapping#.models.jmespath');
    }

}
