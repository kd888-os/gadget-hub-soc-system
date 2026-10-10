using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Text.Json;
using DistributorPortal.Models;

namespace DistributorPortal.Controllers
{
    public class QuotationsController : Controller
    {
        private readonly HttpClient _httpClient;

        public QuotationsController(IHttpClientFactory httpClientFactory)
        {
            _httpClient = httpClientFactory.CreateClient();
            _httpClient.BaseAddress = new Uri("http://localhost:5001");
        }

        public async Task<IActionResult> Details(int id)
        {
            if (HttpContext.Session.GetInt32("StaffId") == null)
                return RedirectToAction("Login", "Auth");

            var distributorName = HttpContext.Session.GetString("DistributorName");

            try
            {
                var url = $"/api/distributor/{Uri.EscapeDataString(distributorName)}/quotations/{id}/details";
                Console.WriteLine($"[PORTAL] Fetching details: {url}");

                var response = await _httpClient.GetAsync(url);
                Console.WriteLine($"[PORTAL] Details response: {response.StatusCode}");

                if (response.IsSuccessStatusCode)
                {
                    var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                    var detail = await response.Content.ReadFromJsonAsync<QuotationDetailViewModel>(options);

                    if (detail != null)
                    {
                        ViewBag.StaffName = HttpContext.Session.GetString("StaffName");
                        ViewBag.DistributorName = distributorName;
                        return View(detail);
                    }
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

            TempData["Error"] = "Could not load quotation details.";
            return RedirectToAction("Index", "Dashboard");
        }

        [HttpPost]
        public async Task<IActionResult> Confirm(
            int quotationId,
            string action,
            string distributorOrderId,
            string estimatedDeliveryDays,
            string rejectionReason)
        {
            if (HttpContext.Session.GetInt32("StaffId") == null)
                return RedirectToAction("Login", "Auth");

            var distributorName = HttpContext.Session.GetString("DistributorName");
            var staffName = HttpContext.Session.GetString("StaffName");

            Console.WriteLine($"[PORTAL] Processing quotation #{quotationId} - Action: {action}");

            try
            {
                string finalOrderId = distributorOrderId;

                if (action == "Confirm" && string.IsNullOrEmpty(finalOrderId))
                {
                    var prefix = distributorName == "TechWorld" ? "TW" :
                                 distributorName == "ElectroCom" ? "EC" : "GC";
                    finalOrderId = $"{prefix}-{DateTime.Now:yyyyMMdd}-{new Random().Next(1000, 9999)}";
                    Console.WriteLine($"[PORTAL] Generated Order ID: {finalOrderId}");
                }

                int deliveryDays = 3;
                if (!string.IsNullOrEmpty(estimatedDeliveryDays))
                    int.TryParse(estimatedDeliveryDays, out deliveryDays);

                var payload = new
                {
                    QuotationId = quotationId,
                    DistributorName = distributorName,
                    DistributorOrderId = action == "Confirm" ? finalOrderId : "",
                    EstimatedDeliveryDate = DateTime.Now.AddDays(deliveryDays),
                    Status = action == "Confirm" ? "Confirmed" : "Rejected",
                    RejectionReason = rejectionReason ?? "",
                    ConfirmedBy = staffName
                };

                var response = await _httpClient.PostAsJsonAsync(
                    "/api/distributor/quotations/confirm", payload);

                var body = await response.Content.ReadAsStringAsync();
                Console.WriteLine($"[PORTAL] Confirm response: {response.StatusCode} - {body}");

                if (response.IsSuccessStatusCode)
                {
                    TempData["Success"] = action == "Confirm"
                        ? $"✓ Order confirmed! Your Order ID: {finalOrderId}"
                        : "Quotation rejected.";
                }
                else
                {
                    TempData["Error"] = body.Contains("already been confirmed")
                        ? "⚠️ Another distributor already confirmed this order!"
                        : $"Failed to process: {body}";
                }
            }
            catch (Exception ex)
            {
                TempData["Error"] = $"Error: {ex.Message}";
            }

            return RedirectToAction("Index", "Dashboard");
        }
    }
}