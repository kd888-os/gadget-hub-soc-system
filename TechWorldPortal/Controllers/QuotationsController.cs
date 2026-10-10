using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using TechWorldPortal.Models;

namespace TechWorldPortal.Controllers
{
    public class QuotationsController : Controller
    {
        private readonly HttpClient _httpClient;

        public QuotationsController(IHttpClientFactory httpClientFactory)
        {
            _httpClient = httpClientFactory.CreateClient();
        }

        public async Task<IActionResult> Details(int id)
        {
            if (HttpContext.Session.GetInt32("StaffId") == null)
                return RedirectToAction("Login", "Auth");

            try
            {
                var response = await _httpClient.GetAsync($"http://localhost:5101/api/techworld/quotations/{id}");

                if (response.IsSuccessStatusCode)
                {
                    var quotation = await response.Content.ReadFromJsonAsync<QuotationRequestViewModel>();
                    ViewBag.StaffName = HttpContext.Session.GetString("StaffName");
                    return View(quotation);
                }
            }
            catch { }

            return RedirectToAction("Index", "Dashboard");
        }

        [HttpPost]
        public async Task<IActionResult> Confirm(ConfirmQuotationViewModel model)
        {
            if (HttpContext.Session.GetInt32("StaffId") == null)
                return RedirectToAction("Login", "Auth");

            try
            {
                if (model.Action == "Confirm")
                {
                    // Generate order ID if not provided
                    if (string.IsNullOrEmpty(model.DistributorOrderId))
                    {
                        model.DistributorOrderId = $"TW-{DateTime.Now:yyyyMMdd}-{new Random().Next(1000, 9999)}";
                    }

                    // Set estimated delivery date if not provided (3 days for TechWorld)
                    if (!model.EstimatedDeliveryDate.HasValue)
                    {
                        model.EstimatedDeliveryDate = DateTime.Now.AddDays(3);
                    }
                }

                var response = await _httpClient.PostAsJsonAsync(
                    $"http://localhost:5101/api/techworld/quotations/{model.QuotationId}/confirm",
                    model
                );

                if (response.IsSuccessStatusCode)
                {
                    TempData["Success"] = model.Action == "Confirm"
                        ? "Quotation confirmed successfully!"
                        : "Quotation rejected.";
                }
                else
                {
                    TempData["Error"] = "Failed to process quotation";
                }
            }
            catch
            {
                TempData["Error"] = "Unable to connect to service";
            }

            return RedirectToAction("Index", "Dashboard");
        }
    }
}