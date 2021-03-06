require 'parse-ruby-client'
require 'scraperwiki'

# It really doesn't seem to be a terribly good idea having the api_key exposed to anyone
# but that seems to be how they're doing things. See
# https://data.sa.gov.au/storage/f/2014-06-25T01%3A10%3A05.960Z/parse-api-instruction-document-unleashed-v2.pdf

Parse.init :application_id => "LvLKTxvA2LGOTJAXTZhblO4E1f04miKymXsHRGaO",
           :api_key        => "gOVgfFHKJviaYhujxhH7kc9T9KoFmsrjwLvlSEqo",
           :quiet          => true

def process_contacts(contacts)
  contacts.each do |contact|
    query = Parse::Query.new("council")
    query.eq("councilId", contact["ownerId"])
    council = query.get.first

    # This is an HTML snippet with a heap of contact details.
    renderedContent = contact["renderedContent"]
    # Crudely extract the email address.
    email = renderedContent[/"mailto:([^"]+)"/, 1] or
            renderedContent[/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-z]{2,4}/, 0]

    record = {
      "name" => contact["name"],
      "position" => contact["position"],
      "updated_at" => contact["updatedAt"],
      "url" => contact["url"],
      "ward" => contact["ward"],
      "email" => email
    }
    if council
      if council["website"] and not council["website"].empty?
        council_url = council["website"]
      else
        council_url = contact["url"][/^(http:\/\/)?([^\/]+)/, 2]
      end
      record["council"] = council["name"]
      record["council_url"] = council_url
    else
      puts "No council data: #{record}"
    end
    puts "No email found: #{record}" if not email

    p record
    ScraperWiki.save_sqlite(["url", "name"], record)
  end
end

skip = 0
loop do
  contacts = Parse::Query.new("contact").tap do |q|
    q.limit = 100
    q.skip = skip
  end.get
  break if contacts.empty?
  skip += 100
  process_contacts(contacts)
end
