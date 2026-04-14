defmodule AccessGuardian.Access.Validations.RequireStatus do
  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    case Keyword.fetch(opts, :status) do
      {:ok, _} -> {:ok, opts}
      :error -> {:error, "status option is required"}
    end
  end

  @impl true
  def validate(changeset, opts, _context) do
    expected = Keyword.fetch!(opts, :status)
    expected = if is_list(expected), do: expected, else: [expected]
    current = Ash.Changeset.get_attribute(changeset, :status)

    if current in expected do
      :ok
    else
      {:error, field: :status, message: "must be #{inspect(expected)}, got #{inspect(current)}"}
    end
  end
end
