require 'rails_helper'

RSpec.describe WishListLinkPreview do
  def stub_dns(host, ip)
    allow(Resolv).to receive(:getaddresses).with(host).and_return([ ip ])
  end

  def html_with(title: nil, image: nil, price: nil, site_name: nil, plain_title: nil)
    tags = []
    tags << %(<meta property="og:title" content="#{title}">) if title
    tags << %(<meta property="og:image" content="#{image}">) if image
    tags << %(<meta property="product:price:amount" content="#{price}">) if price
    tags << %(<meta property="og:site_name" content="#{site_name}">) if site_name
    "<html><head>#{tags.join}<title>#{plain_title}</title></head><body></body></html>"
  end

  describe "SSRF protection" do
    it "rejects loopback IP literals" do
      expect(described_class.fetch("http://127.0.0.1/")).to be_nil
    end

    it "rejects private IP literals" do
      expect(described_class.fetch("http://10.0.0.5/")).to be_nil
      expect(described_class.fetch("http://172.16.0.5/")).to be_nil
      expect(described_class.fetch("http://192.168.1.5/")).to be_nil
    end

    it "rejects the cloud metadata link-local address" do
      expect(described_class.fetch("http://169.254.169.254/")).to be_nil
    end

    it "rejects the 0.0.0.0/8 network" do
      expect(described_class.fetch("http://0.0.0.5/")).to be_nil
    end

    it "rejects localhost by name" do
      expect(described_class.fetch("http://localhost/")).to be_nil
      expect(described_class.fetch("http://LOCALHOST/")).to be_nil
    end

    it "rejects non-http(s) schemes" do
      expect(described_class.fetch("ftp://example.com/file")).to be_nil
      expect(described_class.fetch("file:///etc/passwd")).to be_nil
    end

    it "rejects an unparsable url" do
      expect(described_class.fetch("not a url")).to be_nil
    end

    it "rejects a hostname that resolves to a private IP" do
      stub_dns("internal.example.com", "10.1.2.3")
      expect(described_class.fetch("https://internal.example.com/")).to be_nil
    end

    it "rejects a redirect that points at a private IP (DNS-rebinding-style bypass)" do
      stub_dns("store.example.com", "93.184.216.1")
      stub_dns("internal.example.com", "10.1.2.3")
      stub_request(:get, "https://store.example.com/product")
        .to_return(status: 302, headers: { "Location" => "https://internal.example.com/" })

      expect(described_class.fetch("https://store.example.com/product")).to be_nil
    end
  end

  describe "successful fetch" do
    it "extracts og tags into a Result" do
      stub_dns("store.example.com", "93.184.216.1")
      stub_request(:get, "https://store.example.com/product").to_return(
        status: 200,
        headers: { "Content-Type" => "text/html" },
        body: html_with(
          title: "Wooden Play Gym",
          image: "/images/play-gym.jpg",
          price: "140.00",
          site_name: "Lovevery"
        )
      )

      result = described_class.fetch("https://store.example.com/product")

      expect(result.title).to eq("Wooden Play Gym")
      expect(result.image_url).to eq("https://store.example.com/images/play-gym.jpg")
      expect(result.price).to eq("140.00")
      expect(result.store).to eq("Lovevery")
    end

    it "falls back to the <title> tag and the host when og tags are missing" do
      stub_dns("store.example.com", "93.184.216.1")
      stub_request(:get, "https://store.example.com/product").to_return(
        status: 200,
        headers: { "Content-Type" => "text/html" },
        body: html_with(plain_title: "Plain Product Page")
      )

      result = described_class.fetch("https://store.example.com/product")

      expect(result.title).to eq("Plain Product Page")
      expect(result.store).to eq("store.example.com")
      expect(result.image_url).to be_nil
    end

    it "returns nil when there is no title at all" do
      stub_dns("store.example.com", "93.184.216.1")
      stub_request(:get, "https://store.example.com/product").to_return(
        status: 200,
        headers: { "Content-Type" => "text/html" },
        body: "<html><head></head><body>no title here</body></html>"
      )

      expect(described_class.fetch("https://store.example.com/product")).to be_nil
    end

    it "follows a redirect to a safe host" do
      stub_dns("short.example.com", "93.184.216.1")
      stub_dns("store.example.com", "93.184.216.2")
      stub_request(:get, "https://short.example.com/p/1")
        .to_return(status: 301, headers: { "Location" => "https://store.example.com/product" })
      stub_request(:get, "https://store.example.com/product").to_return(
        status: 200,
        headers: { "Content-Type" => "text/html" },
        body: html_with(title: "Redirected Product")
      )

      result = described_class.fetch("https://short.example.com/p/1")
      expect(result.title).to eq("Redirected Product")
    end
  end

  describe "resilience" do
    it "returns nil for a non-2xx response" do
      stub_dns("store.example.com", "93.184.216.1")
      stub_request(:get, "https://store.example.com/product").to_return(status: 404)

      expect(described_class.fetch("https://store.example.com/product")).to be_nil
    end

    it "returns nil for a non-html content type without attempting to parse it" do
      stub_dns("store.example.com", "93.184.216.1")
      stub_request(:get, "https://store.example.com/photo.png")
        .to_return(status: 200, headers: { "Content-Type" => "image/png" }, body: "\x89PNG")

      expect(described_class.fetch("https://store.example.com/photo.png")).to be_nil
    end

    it "returns nil after exceeding the redirect cap instead of following forever" do
      stub_dns("loop.example.com", "93.184.216.1")
      stub_request(:get, "https://loop.example.com/a")
        .to_return(status: 302, headers: { "Location" => "https://loop.example.com/b" })
      stub_request(:get, "https://loop.example.com/b")
        .to_return(status: 302, headers: { "Location" => "https://loop.example.com/c" })
      stub_request(:get, "https://loop.example.com/c")
        .to_return(status: 302, headers: { "Location" => "https://loop.example.com/d" })
      stub_request(:get, "https://loop.example.com/d")
        .to_return(status: 302, headers: { "Location" => "https://loop.example.com/e" })

      expect(described_class.fetch("https://loop.example.com/a")).to be_nil
    end

    it "caps how much of the body it reads" do
      stub_const("WishListLinkPreview::MAX_BODY_BYTES", 60)
      stub_dns("store.example.com", "93.184.216.1")
      padding = "x" * 100
      body = %(<html><head><meta property="og:title" content="Capped">) + padding + "</head></html>"
      stub_request(:get, "https://store.example.com/product")
        .to_return(status: 200, headers: { "Content-Type" => "text/html" }, body: body)

      result = described_class.fetch("https://store.example.com/product")
      expect(result.title).to eq("Capped")
    end

    it "never raises, even when the request itself errors" do
      stub_dns("store.example.com", "93.184.216.1")
      stub_request(:get, "https://store.example.com/product").to_timeout

      expect { described_class.fetch("https://store.example.com/product") }.not_to raise_error
      expect(described_class.fetch("https://store.example.com/product")).to be_nil
    end
  end
end
