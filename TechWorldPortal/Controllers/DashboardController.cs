using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using System.Collections.Generic;
using TechWorldPortal.Models;

namespace TechWorldPortal.Controllers
{
    public class DashboardController : Controller
    {
        private readonly HttpClient _httpClient;

        public DashboardController(IHttpClientFactory httpClientFactory)
        {
            _httpClient = httpClientFactory.CreateClient();
        }

        public async Task<IActionResult> Index()
        {
            if (HttpContext.Session.GetInt32("StaffId") == null)
                return RedirectToAction("Login", "Auth");

            try
            {
                // Get pending quotations from TechWorld API
                var response = await _httpClient.GetAsync("http://localhost:5101/api/techworld/quotations/pending");

                if (response.IsSuccessStatusCode)
                {
                    var quotations = await response.Content.ReadFromJsonAsync<List<QuotationRequestViewModel>>();

                    var dashboard = new DashboardViewModel
                    {
                        PendingQuotations = quotations?.Count ?? 0,
                        RecentQuotations = quotations ?? new List<QuotationRequestViewModel>()
                    };

                    ViewBag.StaffName = HttpContext.Session.GetString("StaffName");
                    return View(dashboard);
                }
            }
            catch { }

            ViewBag.StaffName = HttpContext.Session.GetString("StaffName");
            return View(new DashboardViewModel { RecentQuotations = new List<QuotationRequestViewModel>() });
        }
    }
}