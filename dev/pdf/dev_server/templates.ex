defmodule Pdf.DevServer.Templates do
  @moduledoc false

  def render_index(categories, initial_path) do
    sidebar_html =
      categories
      |> Enum.map(fn {cat_id, cat_name, examples} ->
        buttons =
          examples
          |> Enum.map(fn {id, name, desc, _fun} ->
            """
            <button
              onclick="loadPdf('#{cat_id}', '#{id}')"
              class="example-btn w-full text-left px-4 py-3 rounded-lg border border-gray-200 hover:border-indigo-400 hover:bg-indigo-50 transition-all duration-150 group"
              data-id="#{cat_id}/#{id}"
            >
              <div class="font-medium text-gray-800 group-hover:text-indigo-700">#{name}</div>
              <div class="text-xs text-gray-500 mt-0.5">#{desc}</div>
            </button>
            """
          end)
          |> Enum.join("\n")

        """
        <div class="mb-4">
          <h3 class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2 px-1">#{cat_name}</h3>
          <div class="space-y-2">#{buttons}</div>
        </div>
        """
      end)
      |> Enum.join("\n")

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Pdf Dev Server</title>
      <script src="https://cdn.tailwindcss.com"></script>
      <style>
        body { font-family: 'Inter', system-ui, -apple-system, sans-serif; }
        .example-btn.active { border-color: #6366f1; background: #eef2ff; }
        .example-btn.active .font-medium { color: #4338ca; }
        #pdf-frame { min-height: 100%; }
        .sidebar { scrollbar-width: thin; }
        .sidebar::-webkit-scrollbar { width: 6px; }
        .sidebar::-webkit-scrollbar-thumb { background: #d1d5db; border-radius: 3px; }
        .loading { display: none; }
        .loading.show { display: flex; }
      </style>
    </head>
    <body class="bg-gray-50 h-screen flex flex-col overflow-hidden">
      <!-- Header -->
      <header class="bg-white border-b border-gray-200 px-6 py-3 flex items-center justify-between shrink-0">
        <div class="flex items-center gap-3">
          <div class="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center">
            <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
          </div>
          <div>
            <h1 class="text-lg font-bold text-gray-900">Pdf Dev Server</h1>
            <p class="text-xs text-gray-500">Preview & test PDF designs</p>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <button onclick="refreshPdf()" class="px-3 py-1.5 text-sm bg-gray-100 hover:bg-gray-200 rounded-md transition-colors" title="Reload current PDF">
            <svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
            </svg>
            Reload
          </button>
          <a id="download-btn" href="#" download class="px-3 py-1.5 text-sm bg-indigo-600 text-white hover:bg-indigo-700 rounded-md transition-colors hidden">
            <svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
            Download
          </a>
        </div>
      </header>

      <!-- Main -->
      <div class="flex flex-1 overflow-hidden">
        <!-- Sidebar -->
        <aside class="sidebar w-80 bg-white border-r border-gray-200 p-4 overflow-y-auto shrink-0">
          #{sidebar_html}
        </aside>

        <!-- Preview -->
        <main class="flex-1 bg-gray-100 relative">
          <!-- Empty state -->
          <div id="empty-state" class="absolute inset-0 flex items-center justify-center">
            <div class="text-center">
              <svg class="w-16 h-16 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
              </svg>
              <p class="text-gray-400 text-lg">Select an example to preview</p>
            </div>
          </div>

          <!-- Loading -->
          <div id="loading" class="loading absolute inset-0 items-center justify-center bg-gray-100/80 z-10">
            <div class="flex items-center gap-3 bg-white px-6 py-3 rounded-lg shadow-sm">
              <svg class="animate-spin w-5 h-5 text-indigo-600" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
              </svg>
              <span class="text-gray-600">Generating PDF...</span>
            </div>
          </div>

          <!-- PDF iframe -->
          <iframe id="pdf-frame" class="w-full h-full hidden" frameborder="0"></iframe>
        </main>
      </div>

      <script>
        let currentId = null;
        let currentCategory = null;

        function loadPdf(category, id, skipPush) {
          currentId = category + '/' + id;
          currentCategory = category;

          // Update URL without reload
          if (!skipPush) {
            history.pushState({cat: category, id: id}, '', '/view/' + category + '/' + id);
          }

          // Update active button
          document.querySelectorAll('.example-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.id === currentId);
          });

          // Show loading
          document.getElementById('loading').classList.add('show');
          document.getElementById('empty-state').classList.add('hidden');

          // Load PDF
          const frame = document.getElementById('pdf-frame');
          const url = '/pdf/' + category + '/' + id + '?t=' + Date.now();
          frame.src = url;
          frame.classList.remove('hidden');
          frame.onload = function() {
            document.getElementById('loading').classList.remove('show');
          };

          // Update download button
          const dlBtn = document.getElementById('download-btn');
          dlBtn.href = '/pdf/' + category + '/' + id;
          dlBtn.download = id + '.pdf';
          dlBtn.classList.remove('hidden');
        }

        function refreshPdf() {
          if (currentId && currentCategory) {
            const id = currentId.split('/').pop();
            loadPdf(currentCategory, id, true);
          }
        }

        // Handle browser back/forward
        window.addEventListener('popstate', function(e) {
          if (e.state && e.state.cat && e.state.id) {
            loadPdf(e.state.cat, e.state.id, true);
          }
        });

        // Keyboard shortcut: R to reload
        document.addEventListener('keydown', function(e) {
          if (e.key === 'r' && !e.ctrlKey && !e.metaKey && document.activeElement.tagName !== 'INPUT') {
            refreshPdf();
          }
        });

        // Auto-load example from initial path (server-side or URL)
        (function() {
          const initial = '#{initial_path || ""}';
          if (initial) {
            const parts = initial.split('/');
            const id = parts.pop();
            const cat = parts.join('/');
            if (cat && id) loadPdf(cat, id, true);
          }
        })();
      </script>
    </body>
    </html>
    """
  end
end
