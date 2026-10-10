using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using DistributorPortal.Models;

namespace DistributorPortal.Controllers
{
    public class DashboardController : Controller
    {
        private readonly HttpClient _httpClient;

        public DashboardController(IHttpClientFactory httpClientFactory)
        {
            _httpClient = httpClientFactory.CreateClient();
            _httpClient.BaseAddress = new Uri("http://localhost:5001");
        }

        public async Task<IActionResult> Index()
        {
            if (HttpContext.Session.GetInt32("StaffId") == null)
                return RedirectToAction("Login", "Auth");

            var staffName = HttpContext.Session.GetString("StaffName");
            var distributorName = HttpContext.Session.GetString("DistributorName");

            Console.WriteLine($"[PORTAL] Loading dashboard for {staffName} ({distributorName})");

            var quotations = new List<QuotationViewModel>();

            try
            {
                var url = $"/api/distributor/{Uri.EscapeDataString(distributorName)}/quotations";
                Console.WriteLine($"[PORTAL] Fetching: {url}");

                var response = await _httpClient.GetAsync(url);
                Console.WriteLine($"[PORTAL] Response: {response.StatusCode}");

                if (response.IsSuccessStatusCode)
                {
                    var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                    quotations = await response.Content.ReadFromJsonAsync<List<QuotationViewModel>>(options)
                                 ?? new List<QuotationViewModel>();

                    Console.WriteLine($"[PORTAL] Loaded {quotations.Count} quotations");
                }
                else
                {
                    var err = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"[PORTAL] Error: {err}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[PORTAL] Exception: {ex.Message}");
            }

            var dashboard = new DashboardViewModel
            {
                StaffName = staffName,
                DistributorName = distributorName,
                TotalQuotations = quotations.Count,
                PendingQuotations = quotations.Count(q => q.Status == "Pending"),
                ConfirmedToday = quotations.Count(q =>
                    q.Status == "Confirmed" &&
                    q.ConfirmedDate.HasValue &&
                    q.ConfirmedDate.Value.Date == DateTime.Today),
                RevenueToday = quotations
                    .Where(q => q.Status == "Confirmed" &&
                                q.ConfirmedDate.HasValue &&
                                q.ConfirmedDate.Value.Date == DateTime.Today)
                    .Sum(q => q.TotalPrice),
                RecentQuotations = quotations
            };

            return View(dashboard);
        }
    }
}