using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Text.Json;
using AdminPortal.Models;

namespace AdminPortal.Controllers
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
            if (HttpContext.Session.GetInt32("AdminId") == null)
                return RedirectToAction("Login", "Auth");

            var adminName = HttpContext.Session.GetString("AdminName");
            Console.WriteLine($"[ADMIN PORTAL] Loading dashboard for {adminName}");

            var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

            // Get statistics
            var stats = new StatisticsResponse();
            try
            {
                var statsResponse = await _httpClient.GetAsync("/api/admin/statistics");
                Console.WriteLine($"[ADMIN PORTAL] Stats response: {statsResponse.StatusCode}");
                if (statsResponse.IsSuccessStatusCode)
                {
                    stats = await statsResponse.Content.ReadFromJsonAsync<StatisticsResponse>(options)
                            ?? new StatisticsResponse();
                }
                else
                {
                    var err = await statsResponse.Content.ReadAsStringAsync();
                    Console.WriteLine($"[ADMIN PORTAL] Stats error: {err}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ADMIN PORTAL] Stats exception: {ex.Message}");
            }

            // Get orders
            var orders = new List<OrderViewModel>();
            try
            {
                var ordersResponse = await _httpClient.GetAsync("/api/admin/orders");
                Console.WriteLine($"[ADMIN PORTAL] Orders response: {ordersResponse.StatusCode}");
                if (ordersResponse.IsSuccessStatusCode)
                {
                    orders = await ordersResponse.Content.ReadFromJsonAsync<List<OrderViewModel>>(options)
                             ?? new List<OrderViewModel>();
                    Console.WriteLine($"[ADMIN PORTAL] Loaded {orders.Count} orders");
                }
                else
                {
                    var err = await ordersResponse.Content.ReadAsStringAsync();
                    Console.WriteLine($"[ADMIN PORTAL] Orders error: {err}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ADMIN PORTAL] Orders exception: {ex.Message}");
            }

            // Get quotations
            var quotations = new List<QuotationViewModel>();
            try
            {
                var quotationsResponse = await _httpClient.GetAsync("/api/admin/quotations");
                Console.WriteLine($"[ADMIN PORTAL] Quotations response: {quotationsResponse.StatusCode}");
                if (quotationsResponse.IsSuccessStatusCode)
                {
                    quotations = await quotationsResponse.Content.ReadFromJsonAsync<List<QuotationViewModel>>(options)
                                 ?? new List<QuotationViewModel>();
                    Console.WriteLine($"[ADMIN PORTAL] Loaded {quotations.Count} quotations");
                }
                else
                {
                    var err = await quotationsResponse.Content.ReadAsStringAsync();
                    Console.WriteLine($"[ADMIN PORTAL] Quotations error: {err}");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ADMIN PORTAL] Quotations exception: {ex.Message}");
            }

            var dashboard = new DashboardViewModel
            {
                AdminName = adminName,
                TotalOrders = stats.TotalOrders,
                TotalRevenue = stats.TotalRevenue,
                TotalCustomers = stats.TotalCustomers,
                TotalProducts = stats.TotalProducts,
                OrdersToday = stats.OrdersToday,
                RevenueToday = stats.RevenueToday,
                RecentOrders = orders,
                RecentQuotations = quotations
            };

            return View(dashboard);
        }
    }

    public class StatisticsResponse
    {
        public int TotalOrders { get; set; }
        public decimal TotalRevenue { get; set; }
        public int TotalCustomers { get; set; }
        public int TotalProducts { get; set; }
        public int OrdersToday { get; set; }
        public decimal RevenueToday { get; set; }
    }
}
























