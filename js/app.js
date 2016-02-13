// Log levels
my.loglevel = 2; // recommended for production is 2
Ractive.DEBUG = (my.loglevel >= 4);
console.log ('loglevel is', my.loglevel);

// loading Config
var default_hjson = 'config.defaults.hjson',
	user_hjson = (window.location.host+window.location.pathname == 'alexylem.github.io/projectpage/')?default_hjson:'config.hjson'; // hack for Projectpage website

my.debug ('retrieving config file at', user_hjson);
$.ajax ({
	url: user_hjson,
	dataType: 'text',
	success: function (sconfig) {
		my.debug ('user has created config.hjson, using it');
		buildpage (Hjson.parse (sconfig));
	},
	error: function(XMLHttpRequest, textStatus, errorThrown) {
		console.warn ('user has not yet created config.hjson, using default');
		$.ajax ({
			url: default_hjson,
			dataType: 'text',
			success: function (sconfig) {
				// default json found, appending Warning
				var config = Hjson.parse (sconfig);
				config.sections.unshift ({
					text: '> :warning: `config.hjson` not found, using `config.defaults.hjson`.  \n'+
						  'Please create `config.hjson` from a copy of `config.defaults.hjson`.  \n'+
						  'More information available in the [documentation](http://alexylem.github.io/projectpage/).'
				});
				buildpage (config);
			},
			error: function (XMLHttpRequest, textStatus, errorThrown) {
				// default hjson not found, showing error
				var error = textStatus+';'+XMLHttpRequest.responseText+';'+errorThrown,
				 	config = {
					title: 'Error',
					sections: [{
						title: 'Error',
						text: error,
						image: '',
					}]
				};
				console.error ('Error '+XMLHttpRequest.status+' from '+hjson+': ', error);
				buildpage (config);
			}
		});
	}
});

function buildpage (config) {
	my.debug ('building page with config', config);
	
	// theme
	var css = 'lib/bootstrap-3.3.6-dist/css/bootstrap.min.css';
	if (config.theme)
		css = '//bootswatch.com/'+config.theme+'/bootstrap.min.css';
	$('<link href="'+css+'" rel="stylesheet" />').appendTo('head');

	var Page = new Ractive({
		el: 'container',
		template: '#template',
		data: config, // js/config.js
		oncomplete: function () {
			my.debug ('onrender');
			// Page title
			document.title = this.get('title');

			// Scroll Spy
			$('body').scrollspy({
				target: '#navbar',
				offset: 70
			});

			// Markdown
			var md = window.markdownit({
				html: true,
				highlight: function (str, lang) {
					if (lang && hljs.getLanguage(lang)) {
						try {
							return hljs.highlight(lang, str).value;
						} catch (__) {}
					}
					try {
						return hljs.highlightAuto(str).value;
					} catch (__) {}
					return ''; // use external default escaping
				}
			}).use(window.markdownitEmoji);
			md.renderer.rules.emoji = function(token, idx) {
				return twemoji.parse(token[idx].content);
			};
			$('p.markdown').each (function (){
				var $this = $(this);
				$this.html (md.render($this.text()));
			});
			// Add bootstrap table classes
			$("table").addClass("table table-striped table-condensed table-bordered");

			// Disqus Comments
			if (this.get('comments')) {
				/*
				// https://disqus.com/admin/universalcode/#configuration-variables
				var disqus_config = function () {
				this.page.url = PAGE_URL; // Replace PAGE_URL with your page's canonical URL variable
				this.page.identifier = PAGE_IDENTIFIER; // Replace PAGE_IDENTIFIER with your page's unique identifier variable
				};
				*/
				var d = document, s = d.createElement('script');
				s.src = '//'+this.get('disqus_shortname')+'.disqus.com/embed.js';
				s.setAttribute('data-timestamp', +new Date());
				(d.head || d.body).appendChild(s);
			}
		}
	});
}
