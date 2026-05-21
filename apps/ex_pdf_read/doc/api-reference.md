# ex_pdf_read v1.0.0 - API Reference

## Modules

- [Pdf.Reader](Pdf.Reader.md): Native PDF reader — opens a PDF binary or file path and provides pure-functional
access to text runs with positions, raster images, document metadata, interactive
form fields, document outlines (bookmarks), and page annotations.
No GenServer, no mutable state; the reader is a fully lazy, immutable pipeline.
- [Pdf.Reader.AGL](Pdf.Reader.AGL.md): Adobe Glyph List (AGL) — compile-time glyph name to Unicode codepoint lookup.
- [Pdf.Reader.AcroForm](Pdf.Reader.AcroForm.md): AcroForm field walker for `Pdf.Reader`.
- [Pdf.Reader.Annotation](Pdf.Reader.Annotation.md): Represents a single annotation extracted from a PDF page.
- [Pdf.Reader.Annotations](Pdf.Reader.Annotations.md): Walker for per-page `/Annots` arrays.
- [Pdf.Reader.CID.AdobeCNS1](Pdf.Reader.CID.AdobeCNS1.md): Adobe-CNS1 CID to Unicode mapping (~18000 entries).
- [Pdf.Reader.CID.AdobeGB1](Pdf.Reader.CID.AdobeGB1.md): Adobe-GB1 CID to Unicode mapping (~28000 entries).
- [Pdf.Reader.CID.AdobeJapan1](Pdf.Reader.CID.AdobeJapan1.md): Adobe-Japan1 CID to Unicode mapping (~9600 entries).
- [Pdf.Reader.CID.AdobeKorea1](Pdf.Reader.CID.AdobeKorea1.md): Adobe-Korea1 CID to Unicode mapping (~17000 entries).
- [Pdf.Reader.CID.CIDToGIDMap](Pdf.Reader.CID.CIDToGIDMap.md): Parser and lookup for the PDF `/CIDToGIDMap` entry in Type2 CIDFont dicts.
- [Pdf.Reader.CID.CMapParser](Pdf.Reader.CID.CMapParser.md): Minimal PostScript subset parser for Adobe predefined CMap files.
- [Pdf.Reader.CID.Codespace](Pdf.Reader.CID.Codespace.md): Variable-length codespace-aware tokenizer for predefined CMap byte sequences.
- [Pdf.Reader.CID.Decoder](Pdf.Reader.CID.Decoder.md): CID font decoder for Type0/Identity-H and Identity-V composite fonts.
- [Pdf.Reader.CID.PredefinedCMap](Pdf.Reader.CID.PredefinedCMap.md): Lazy loader and lookup for Adobe predefined CMaps bundled in `priv/cmap/`.
- [Pdf.Reader.CMap](Pdf.Reader.CMap.md): Parser for the ToUnicode CMap subset used in PDF fonts.
- [Pdf.Reader.ContentStream](Pdf.Reader.ContentStream.md): PDF content stream interpreter for text and image extraction.
- [Pdf.Reader.Destination](Pdf.Reader.Destination.md): Destination resolution for outline and annotation `/Dest` values.
- [Pdf.Reader.Document](Pdf.Reader.Document.md): Struct representing an open PDF document in the reader.
- [Pdf.Reader.Encoding](Pdf.Reader.Encoding.md): Encoding cascade facade for resolving PDF character codes to Unicode codepoints.
- [Pdf.Reader.Encoding.Differences](Pdf.Reader.Encoding.Differences.md): Applies a PDF `/Differences` array on top of a base encoding override map.
- [Pdf.Reader.Encoding.MacRoman](Pdf.Reader.Encoding.MacRoman.md): Mac OS Roman (MacRomanEncoding) byte-to-Unicode codepoint table.
- [Pdf.Reader.Encoding.StandardEncoding](Pdf.Reader.Encoding.StandardEncoding.md): PDF Standard Encoding — byte-to-Unicode codepoint table.
- [Pdf.Reader.Encoding.WinAnsi](Pdf.Reader.Encoding.WinAnsi.md): WinAnsi (Windows-1252 / CP1252) encoding — read direction.
- [Pdf.Reader.Encryption](Pdf.Reader.Encryption.md): Facade module for PDF Standard Security Handler authentication and decryption.
- [Pdf.Reader.Encryption.ObjectKey](Pdf.Reader.Encryption.ObjectKey.md): Derives the per-object encryption key used for V1, V2, and V4 Standard
Security Handler streams and strings.
- [Pdf.Reader.Encryption.PasswordPad](Pdf.Reader.Encryption.PasswordPad.md): Provides the canonical 32-byte PDF password-padding constant and a helper
to pad (or truncate) an arbitrary password binary to exactly 32 bytes.
- [Pdf.Reader.Encryption.StandardHandler](Pdf.Reader.Encryption.StandardHandler.md): Parses the PDF `/Encrypt` dictionary into a `%StandardHandler{}` struct.
- [Pdf.Reader.Encryption.V1V2](Pdf.Reader.Encryption.V1V2.md): Implements PDF Standard Security Handler algorithms for V1 (RC4-40) and
V2 (RC4-128) — revisions R=2 and R=3/4.
- [Pdf.Reader.Encryption.V4](Pdf.Reader.Encryption.V4.md): Implements PDF Standard Security Handler algorithms for V4 (Crypt Filters +
AES-128 CBC) — revision R=4.
- [Pdf.Reader.Encryption.V5](Pdf.Reader.Encryption.V5.md): Implements PDF Standard Security Handler algorithms for V5/R6 (AES-256,
PDF 2.0).  R=5 (deprecated Acrobat X beta variant) is explicitly rejected.
- [Pdf.Reader.Errors](Pdf.Reader.Errors.md): Documents the full reason set returned in `{:error, reason}` from `Pdf.Reader`.
- [Pdf.Reader.Filter](Pdf.Reader.Filter.md): PDF stream filter pipeline — behaviour definition and apply_chain dispatcher.
- [Pdf.Reader.Filter.ASCII85](Pdf.Reader.Filter.ASCII85.md): ASCII85Decode filter — decodes ASCII base-85 encoded data to binary.
- [Pdf.Reader.Filter.ASCIIHex](Pdf.Reader.Filter.ASCIIHex.md): ASCIIHexDecode filter — decodes a sequence of hexadecimal digit pairs to
a binary.
- [Pdf.Reader.Filter.Flate](Pdf.Reader.Filter.Flate.md): FlateDecode filter — zlib inflate, with optional PNG and TIFF predictor
un-filtering.
- [Pdf.Reader.Filter.LZW](Pdf.Reader.Filter.LZW.md): LZWDecode filter — decodes LZW compressed data as specified in PDF §7.4.4.
- [Pdf.Reader.Filter.RLE](Pdf.Reader.Filter.RLE.md): RunLengthDecode filter — decodes PackBits-style run-length encoded data.
- [Pdf.Reader.Font](Pdf.Reader.Font.md): Per-font decoder construction for the encoding cascade.
- [Pdf.Reader.Font.Widths](Pdf.Reader.Font.Widths.md): Per-font glyph-width lookup for text advance computation.
- [Pdf.Reader.FormField](Pdf.Reader.FormField.md): Represents a single interactive form field extracted from a PDF AcroForm.
- [Pdf.Reader.GraphicsState](Pdf.Reader.GraphicsState.md): Struct and operations for the PDF graphics state during content stream interpretation.
- [Pdf.Reader.Image](Pdf.Reader.Image.md): Struct representing an image extracted from a PDF page.
- [Pdf.Reader.Images.JPEG](Pdf.Reader.Images.JPEG.md): JPEG (DCTDecode) image utilities for `Pdf.Reader`.
- [Pdf.Reader.Images.PNGLike](Pdf.Reader.Images.PNGLike.md): PNG-like image decoding for `Pdf.Reader`.
- [Pdf.Reader.Lexer](Pdf.Reader.Lexer.md): PDF binary tokenizer.
- [Pdf.Reader.Line](Pdf.Reader.Line.md): Logical text line reconstructed from individual `TextRun`s.
- [Pdf.Reader.ObjectResolver](Pdf.Reader.ObjectResolver.md): Lazy indirect-object resolver with Map-based cache.
- [Pdf.Reader.ObjectStream](Pdf.Reader.ObjectStream.md): Decodes objects embedded in a PDF Object Stream (`/Type /ObjStm`).
- [Pdf.Reader.Outline](Pdf.Reader.Outline.md): Represents a single node in a PDF document outline (bookmark tree).
- [Pdf.Reader.Outlines](Pdf.Reader.Outlines.md): Walker for catalog `/Outlines` (PDF document outline / bookmarks tree).
- [Pdf.Reader.Page](Pdf.Reader.Page.md): Page tree walker for `Pdf.Reader`.
- [Pdf.Reader.Parser](Pdf.Reader.Parser.md): PDF recursive-descent parser.
- [Pdf.Reader.Result](Pdf.Reader.Result.md): Unified extraction result returned by `Pdf.Reader.read/2`.
- [Pdf.Reader.Result.Page](Pdf.Reader.Result.Page.md): Per-page slice of the unified extraction result.
- [Pdf.Reader.Shape](Pdf.Reader.Shape.md): Polymorphic struct describing an "interactive" or actionable element
extracted from a PDF — currently link-like elements (URIs, emails,
intra-document jumps).
- [Pdf.Reader.TextRun](Pdf.Reader.TextRun.md): Struct representing a single text run extracted from a PDF page.
- [Pdf.Reader.Trailer](Pdf.Reader.Trailer.md): Locates the `startxref` byte offset in a PDF binary and parses the
trailer dictionary at a given xref section offset.
- [Pdf.Reader.Utils](Pdf.Reader.Utils.md): Shared utility helpers for `Pdf.Reader` sub-modules.
- [Pdf.Reader.Wordlist](Pdf.Reader.Wordlist.md): Compile-time dictionaries used by `Pdf.Reader.read/2` to recover word
boundaries that the PDF producer collapsed (e.g. `iniciode` →
`inicio` + `de`).
- [Pdf.Reader.XMP](Pdf.Reader.XMP.md): XMP RDF/XML metadata parser.
- [Pdf.Reader.XRef](Pdf.Reader.XRef.md): Facade that dispatches to the appropriate xref reader and follows /Prev chains.
- [Pdf.Reader.XRef.Classic](Pdf.Reader.XRef.Classic.md): Parses a classic PDF cross-reference table (keyword `xref`).
- [Pdf.Reader.XRef.Stream](Pdf.Reader.XRef.Stream.md): Parses a PDF 1.5+ compressed cross-reference stream (`/Type /XRef`).

- Exceptions
  - [Pdf.Reader.Error](Pdf.Reader.Error.md): Exception raised by bang variants of `Pdf.Reader` functions.

