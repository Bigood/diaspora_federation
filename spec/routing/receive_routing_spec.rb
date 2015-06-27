module DiasporaFederation
  describe ReceiveController, type: :routing do
    routes { DiasporaFederation::Engine.routes }

    it "routes POST public" do
      expect(post: "/receive-new/public").to route_to(
        controller: "diaspora_federation/receive",
        action:     "public"
      )
    end

    it "routes POST private" do
      expect(post: "/receive-new/users/1234").to route_to(
        controller: "diaspora_federation/receive",
        action:     "private",
        guid:       "1234"
      )
    end
  end
end
