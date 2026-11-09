defmodule Waves.Billing do
  import Ecto.Query
  alias Waves.{Repo, Invoice}
  @free_limit 5
  def usage(business) do
    issued = Repo.aggregate(from(i in Invoice, where: i.business_id == ^business.id and i.status != "draft"), :count)
    active = business.subscription_status == "active" and
      (is_nil(business.subscription_expires_at) or DateTime.compare(business.subscription_expires_at, DateTime.utc_now()) == :gt)
    %{issued: issued, limit: @free_limit, remaining: max(0, @free_limit - issued), active: active, can_issue: active or issued < @free_limit}
  end
end
