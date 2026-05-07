defmodule Pdf.Reader.AnnotationTest do
  use ExUnit.Case, async: true

  alias Pdf.Reader.Annotation

  # ---------------------------------------------------------------------------
  # Task 2.3 — Annotation struct — field presence, default values,
  #            all 11 subtype atoms, typespec
  # Spec: R-AO15, R-AO16, R-AO17, R-AO18, R-AO19
  # PDF 1.7 § 12.5 — Annotations, § 12.5.6.x — Annotation subtypes
  # ---------------------------------------------------------------------------

  describe "%Pdf.Reader.Annotation{} defaults" do
    @tag :unit
    test ":type defaults to :unknown" do
      assert %Annotation{}.type == :unknown
    end

    @tag :unit
    test ":page defaults to nil" do
      assert %Annotation{}.page == nil
    end

    @tag :unit
    test ":rect defaults to nil" do
      assert %Annotation{}.rect == nil
    end

    @tag :unit
    test ":contents defaults to nil" do
      assert %Annotation{}.contents == nil
    end

    @tag :unit
    test ":title defaults to nil" do
      assert %Annotation{}.title == nil
    end

    @tag :unit
    test ":subject defaults to nil" do
      assert %Annotation{}.subject == nil
    end

    @tag :unit
    test ":created defaults to nil" do
      assert %Annotation{}.created == nil
    end

    @tag :unit
    test ":modified defaults to nil" do
      assert %Annotation{}.modified == nil
    end

    @tag :unit
    test ":dest_page defaults to nil" do
      assert %Annotation{}.dest_page == nil
    end

    @tag :unit
    test ":url defaults to nil" do
      assert %Annotation{}.url == nil
    end

    @tag :unit
    test ":embedded_file_ref defaults to nil" do
      assert %Annotation{}.embedded_file_ref == nil
    end

    @tag :unit
    test ":kind_specific defaults to empty map" do
      assert %Annotation{}.kind_specific == %{}
    end

    @tag :unit
    test "struct has exactly the 13 specified fields" do
      fields = %Annotation{} |> Map.from_struct() |> Map.keys() |> Enum.sort()

      expected = [
        :contents,
        :created,
        :dest_page,
        :embedded_file_ref,
        :kind_specific,
        :modified,
        :page,
        :rect,
        :subject,
        :title,
        :type,
        :url
      ]

      assert fields == expected
    end
  end

  describe "%Pdf.Reader.Annotation{} field assignment — subtype atoms" do
    @tag :unit
    test ":type accepts :link" do
      assert %Annotation{type: :link}.type == :link
    end

    @tag :unit
    test ":type accepts :text" do
      assert %Annotation{type: :text}.type == :text
    end

    @tag :unit
    test ":type accepts :highlight" do
      assert %Annotation{type: :highlight}.type == :highlight
    end

    @tag :unit
    test ":type accepts :underline" do
      assert %Annotation{type: :underline}.type == :underline
    end

    @tag :unit
    test ":type accepts :strikeout" do
      assert %Annotation{type: :strikeout}.type == :strikeout
    end

    @tag :unit
    test ":type accepts :squiggly" do
      assert %Annotation{type: :squiggly}.type == :squiggly
    end

    @tag :unit
    test ":type accepts :square" do
      assert %Annotation{type: :square}.type == :square
    end

    @tag :unit
    test ":type accepts :circle" do
      assert %Annotation{type: :circle}.type == :circle
    end

    @tag :unit
    test ":type accepts :freetext" do
      assert %Annotation{type: :freetext}.type == :freetext
    end

    @tag :unit
    test ":type accepts :file_attachment" do
      assert %Annotation{type: :file_attachment}.type == :file_attachment
    end

    @tag :unit
    test ":type accepts :unknown (explicit)" do
      assert %Annotation{type: :unknown}.type == :unknown
    end
  end

  describe "%Pdf.Reader.Annotation{} field assignment — other fields" do
    @tag :unit
    test ":page accepts a positive integer" do
      assert %Annotation{page: 3}.page == 3
    end

    @tag :unit
    test ":rect accepts a 4-tuple of numbers" do
      assert %Annotation{rect: {10.0, 20.0, 200.0, 300.0}}.rect == {10.0, 20.0, 200.0, 300.0}
    end

    @tag :unit
    test ":contents accepts a string" do
      assert %Annotation{contents: "A note"}.contents == "A note"
    end

    @tag :unit
    test ":url accepts a string" do
      assert %Annotation{url: "https://example.com"}.url == "https://example.com"
    end

    @tag :unit
    test ":embedded_file_ref accepts a {n, g} tuple" do
      assert %Annotation{embedded_file_ref: {5, 0}}.embedded_file_ref == {5, 0}
    end

    @tag :unit
    test ":kind_specific accepts an arbitrary map" do
      ks = %{quad_points: [{0, 0, 1, 0, 0, 1, 1, 1}]}
      assert %Annotation{kind_specific: ks}.kind_specific == ks
    end
  end
end
