using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Linq;
using GadgetHubWeb.Models;

namespace GadgetHubWeb.Controllers
{
    public class OrderController : Controller
    {
        private readonly HttpClient _httpClient;

        public OrderController(IHttpClientFactory httpClientFactory)
        {
            _httpClient = httpClientFactory.CreateClient();
        }

        public async Task<IActionResult> Create()
        {
            // Get customer info from session
            var customerId = HttpContext.Session.GetInt32("CustomerId");
            var customerName = HttpContext.Session.GetString("CustomerName");

            if (customerId == null || string.IsNullOrEmpty(customerName))
            {
                return RedirectToAction("Index", "Login");
            }

            try
            {
                // Get products from OrderAPI
                var response = await _httpClient.GetAsync("http://localhost:5001/api/products");

                if (response.IsSuccessStatusCode)
                {
                    var products = await response.Content.ReadFromJsonAsync<List<Product>>();

                    // Pass customer data to view
                    ViewBag.CustomerId = customerId.Value;
                    ViewBag.CustomerName = customerName;

                    return View(products);
                }
            }
            catch (System.Exception ex)
            {
                System.Console.WriteLine($"[WEB APP] Error loading products: {ex.Message}");
            }

            // Pass customer data even if products fail to load
            ViewBag.CustomerId = customerId.Value;
            ViewBag.CustomerName = customerName;

            return View(new List<Product>());
        }

        [HttpPost]
        public async Task<IActionResult> PlaceOrder(OrderRequest orderRequest)
        {
            try
            {
                System.Console.WriteLine($"[WEB APP] Placing order for {orderRequest.CustomerName} with {orderRequest.Items?.Count ?? 0} items");

                if (orderRequest.Items == null || orderRequest.Items.Count == 0)
                {
                    TempData["Error"] = "Your cart is empty!";
                    return RedirectToAction("Create");
                }

                // Call OrderAPI to place order
                var response = await _httpClient.PostAsJsonAsync("http://localhost:5001/api/orders", orderRequest);

                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadFromJsonAsync<OrderResponse>();

                    System.Console.WriteLine($"[WEB APP] Order placed successfully: Order #{result.OrderId}");

                    // Store order result in TempData for success page (convert types to serializable)
                    TempData["OrderId"] = result.OrderId;
                    TempData["TotalAmount"] = result.TotalAmount.ToString("F2");  // Convert decimal to string
                    TempData["SelectedDistributor"] = result.SelectedDistributor;
                    TempData["IsSplitOrder"] = result.IsSplitOrder;
                    TempData["DeliveryDays"] = result.DeliveryDays;
                    TempData["Message"] = result.Message;

                    // If distributions exist, serialize them
                    if (result.Distributions != null && result.Distributions.Any())
                    {
                        TempData["Distributions"] = System.Text.Json.JsonSerializer.Serialize(result.Distributions);
                    }

                    return RedirectToAction("Success");
                }
                else
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    System.Console.WriteLine($"[WEB APP] Order failed: {errorContent}");
                    TempData["Error"] = "Failed to place order. Please try again.";
                    return RedirectToAction("Create");
                }
            }
            catch (System.Exception ex)
            {
                System.Console.WriteLine($"[WEB APP] Error placing order: {ex.Message}");
                TempData["Error"] = "An error occurred while placing your order.";
                return RedirectToAction("Create");
            }
        }

        public IActionResult Success()
        {
            // Check if we have order data
            if (TempData["OrderId"] == null)
            {
                return RedirectToAction("Create");
            }

            // Build OrderResponse from TempData (parse string back to decimal)
            var orderResponse = new OrderResponse
            {
                Success = true,
                OrderId = (int)TempData["OrderId"],
                TotalAmount = decimal.Parse(TempData["TotalAmount"].ToString()),  // Parse string back to decimal
                SelectedDistributor = TempData["SelectedDistributor"]?.ToString(),
                IsSplitOrder = TempData["IsSplitOrder"] != null && (bool)TempData["IsSplitOrder"],
                DeliveryDays = TempData["DeliveryDays"] != null ? (int)TempData["DeliveryDays"] : null,
                Message = TempData["Message"]?.ToString()
            };

            // Deserialize distributions if they exist
            if (TempData["Distributions"] != null)
            {
                var distributionsJson = TempData["Distributions"].ToString();
                orderResponse.Distributions = System.Text.Json.JsonSerializer.Deserialize<List<DistributionDetail>>(distributionsJson);
            }

            return View(orderResponse);
        }

        public async Task<IActionResult> Status(int id)
        {
            var customerId = HttpContext.Session.GetInt32("CustomerId");
            if (customerId == null)
                return RedirectToAction("Index", "Login");

            try
            {
                var response = await _httpClient.GetAsync(
                    $"http://localhost:5001/api/distributor/orders/{id}/status");

                if (response.IsSuccessStatusCode)
                {
                    var options = new System.Text.Json.JsonSerializerOptions
                    {
                        PropertyNameCaseInsensitive = true
                    };
                    var orderStatus = await response.Content
                        .ReadFromJsonAsync<OrderStatusViewModel>(options);

                    ViewBag.CustomerName = HttpContext.Session.GetString("CustomerName");
                    return View(orderStatus);
                }
            }
            catch (Exception ex)
            {
                System.Console.WriteLine($"[WEB APP] Error fetching status: {ex.Message}");
            }

            TempData["Error"] = "Could not load order status.";
            return RedirectToAction("Create");
        }

        public async Task<IActionResult> MyOrders()
        {
            var customerId = HttpContext.Session.GetInt32("CustomerId");
            var customerName = HttpContext.Session.GetString("CustomerName");

            if (customerId == null)
                return RedirectToAction("Index", "Login");

            try
            {
                var options = new System.Text.Json.JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                };

                var response = await _httpClient.GetAsync(
                    $"http://localhost:5001/api/orders/customer/{customerId}");

                Console.WriteLine($"[WEB APP] MyOrders response: {response.StatusCode}");

                if (response.IsSuccessStatusCode)
                {
                    var orders = await response.Content
                        .ReadFromJsonAsync<List<CustomerOrderViewModel>>(options)
                        ?? new List<CustomerOrderViewModel>();

                    ViewBag.CustomerName = customerName;
                    return View(orders);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[WEB APP] MyOrders error: {ex.Message}");
            }

            ViewBag.CustomerName = customerName;
            return View(new List<CustomerOrderViewModel>());
        }
    }
}