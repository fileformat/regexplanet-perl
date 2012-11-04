use strict;
use warnings;
use HTML::Entities;
use JSON;
use Perl::Version;
use Plack::Request;

my $app = sub {
	my $env = shift;

	if ($env->{PATH_INFO} eq '/')
	{
		return [ 307, ['Location' => 'http://www.regexplanet.com/advanced/perl/index.html'], [ 'See RegexPlanet.com to test your Perl regular expressions' ] ];
	}
	elsif ($env->{PATH_INFO} eq '/status.json')
	{
		my $req = Plack::Request->new($env);
		my $data;

		$data = {
			'$OSNAME' => $^O,
			'$PERL_VERSION' => Perl::Version->new($^V)->stringify,
			'psgi.version' => join("x", $env->{'psgi.version'}),
			'psgi.url_scheme' => $env->{'psgi.url_scheme'},
			'psgi.multithread' => $env->{'psgi.multithread'},
			'psgi.multiprocess' => $env->{'psgi.multiprocess'},
			'psgi.nonblocking' => $env->{'psgi.nonblocking'},
			'psgi.streaming' => $env->{'psgi.streaming'},
			'REMOTE_ADDR' => $env->{REMOTE_ADDR},
			'SERVER_NAME' => $env->{SERVER_NAME},
			'SERVER_PORT' => $env->{SERVER_PORT},
			'SERVER_PROTOCOL' => $env->{SERVER_PROTOCOL},
			"success" => JSON::true,
			};

		my $body = to_json($data, {'utf8' => 1, 'pretty'=> 0});
		my $callback = $req->param('callback');
		if (length($callback))
		{
			$body = $callback . "(" . $body . ")"
		}

		return [200,
			['Content-Length' => length($body), 'Content-Type' => 'text/plain; charset=UTF8', 'Access-Control-Allow-Origin' => '*', 'Access-Control-Allow-Methods' => 'POST, GET', 'Access-Control-Max-Age' => '604800'],
			[$body]];
	}
	elsif ($env->{PATH_INFO} eq '/test.json')
	{
		my $req = Plack::Request->new($env);
		my $regex_str = $req->param('regex');
		my $replacement = $req->param('replacement');
		my $data;

		if (length($regex_str) <= 0)
		{
			$data = { "success" => JSON::false, "message" => "No regex to test" };
		}
		else
		{
			my %options = map { $_ => 1 } $req->parameters->get_all('option');
			my $perl_options = '';
			if ($options{'a'}) { $perl_options .= 'a'; }
			if ($options{'c'}) { $perl_options .= 'c'; }
			if ($options{'d'}) { $perl_options .= 'd'; }
			if ($options{'g'}) { $perl_options .= 'g'; }
			if ($options{'ignorecase'}) { $perl_options .= 'i'; }
			if ($options{'l'}) { $perl_options .= 'l'; }
			if ($options{'multiline'}) { $perl_options .= 'm'; }
			if ($options{'p'}) { $perl_options .= 'p'; }
			if ($options{'dotall'}) { $perl_options .= 's'; }
			if ($options{'unicode'}) { $perl_options .= 'u'; }
			if ($options{'comment'}) { $perl_options .= 'x'; }

			my $regex;
			if (length($perl_options) == 0)
			{
				$regex = qr/$regex_str/;
			}
			else
			{
				$regex = qr/(?$perl_options)$regex_str/;
			}

			my $html = "<table class=\"table table-bordered table-striped\" style=\"width:auto;\">\n"

				. "\t<tr>\n"
				. "\t\t<td>"
				. "Regular expression"
				. "</td>\n"
				. "\t\t<td>"
				. HTML::Entities::encode($regex_str)
				. "</td>\n"
				. "\t</tr>\n"

				. "\t<tr>\n"
				. "\t\t<td>"
				. "Options"
				. "</td>\n"
				. "\t\t<td>"
				. HTML::Entities::encode($perl_options)
				. "</td>\n"
				. "\t</tr>\n"

				. "\t<tr>\n"
				. "\t\t<td>"
				. "Perl code"
				. "</td>\n"
				. "\t\t<td>"
				. 'qr/' . HTML::Entities::encode($regex_str) . '/' . HTML::Entities::encode($perl_options)
				. "</td>\n"
				. "\t</tr>\n";

				if (length($perl_options) > 0)
				{
					$html .= "\t<tr>\n"
					. "\t\t<td>"
					. "Perl code (embedded options)"
					. "</td>\n"
					. "\t\t<td>"
					. 'qr/(?' . HTML::Entities::encode($perl_options) . ')' . HTML::Entities::encode($regex_str) . '/'
					. "</td>\n"
					. "\t</tr>\n";
				}

				$html .= "\t<tr>\n"
				. "\t\t<td>"
				. "Perl variable"
				. "</td>\n"
				. "\t\t<td>"
				. HTML::Entities::encode($regex)
				. "</td>\n"
				. "\t</tr>\n";

				$html .= "</table>";

			$html .= "<table class=\"table table-bordered table-striped\">\n"
				. "\t<thead>"
				. "\t\t<tr>\n"
				. "\t\t\t<th style=\"text-align:center;\">Test</th>\n"
				. "\t\t\t<th>Input</th>\n"
				. "\t\t\t<th style=\"text-align:center;\">=~</th>\n"
				. "\t\t\t<th>split</th>\n"
				. "\t\t\t<th>=~ s/\$regex/\$input/r</th>\n"
				. "\t\t</tr>\n"
				. "\t</thead>\n"
				. "\t<tbody>\n";

			my @inputs = $req->parameters->get_all('input');
			my $count = 0;

			for (my $loop = 0; $loop < scalar(@inputs); $loop++)
			{
				my $input = $inputs[$loop];
				if (length($input) == 0)
				{
					next;
				}
				$html .= "\t\t<tr>"
					. "\t\t\t<td style=\"text-align:center;\">"
					. ($loop + 1)
					. "</td>"
					. "\t\t\t<td>"
					. HTML::Entities::encode($input)
					. "</td>";

				$html .= "\t\t\t<td style=\"text-align:center;\">";
				$html .= ($input =~ $regex);
				$html .= "</td>";

				$html .= "\t\t\t<td>";
				my @words = split $regex, $input;
				for (my $wordLoop = 0; $wordLoop < scalar(@words); $wordLoop++)
				{
					$html .= "[$wordLoop]:&nbsp;" . HTML::Entities::encode($words[$wordLoop]) . "<br/>"
				}
				$html .= "</td>";

				$html .= "\t\t\t<td>";
				# this works locally, but not on dotCloud.  why????
				#my $replaced = $input =~ s/$regex/$replacement/r;
				#$html .= HTML::Entities::encode($replaced);
				$html .= "</td>";

				$html .= "\t\t</tr>";
				$count += 1;
			}

			if ($count == 0)
			{
				$html .= "\t\t<tr>"
					. "\t\t\t<td colspan=\"5\"><i>"
					. "(no inputs to test)"
					. "</i></td>"
					. "\t\t</tr>";
			}

			$html .= "\t</tbody>\n"
				. "</table>\n";


			$data = { "success" => JSON::true, "html" => '<div class="alert alert-warning">Perl support is pretty raw.  If you are a Perl hacker, I could really use some help!  (<a href="http://www.regexplanet.com/support/api.html">instructions</a>, <a href="https://github.com/fileformat/regexplanet-perl">code on GitHub</a>)</div>' . $html};
		}
		my $body = to_json($data, {'utf8' => 1, 'pretty'=> 1});

		return [200,
			['Content-Length' => length($body), 'Content-Type' => 'text/plain; charset=UTF8', 'Access-Control-Allow-Origin' => '*', 'Access-Control-Allow-Methods' => 'POST, GET', 'Access-Control-Max-Age' => '604800'],
			[$body]];
	}
	else
	{
		return [ 404, ['Content-Type' => 'text/plain'], [ "404 Not Found: " + $env->{PATH_INFO} ] ];
	}
};

$app;
