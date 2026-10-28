component {

    this.name = 'JSON-Diff';
    this.title = 'JSON-Diff';
    this.author = 'Scott Steinbeck';
    this.webURL = 'https://github.com/scottsteinbeck/json-diff';
    this.description = 'An ColdFusion utility for checking if 2 JSON objects have differences';
    this.version = '1.0.4';
    this.autoMapModels = false;
    this.dependencies = [];

    function configure() {
        binder.map('jsondiff').to('#moduleMapping#.models.jsondiff');
    }

}