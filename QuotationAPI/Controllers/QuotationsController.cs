using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuotationAPI.Data;
using QuotationAPI.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;

namespace QuotationAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class QuotationsController : ControllerBase
    {
        private readonly QuotationDbContext _context;
        private readonly HttpClient _httpClient;

        public QuotationsController(QuotationDbContext context, IHttpClientFactory httpClientFactory)
        {
            _context = context;
            _httpClient = httpClientFactory.CreateClient();
        }

        /// <summary>
        /// Request quotations from all distributors and intelligently select best options
        /// </summary>
        [HttpPost("request")]
        public async Task<IActionResult> RequestQuotations([FromBody] QuotationRequestDto request)
        {
            try
            {
                Console.WriteLine($"[QUOTATION API] Requesting quotes for Order {request.OrderId} from ALL THREE distributors...");

                // Step 1: Call all three distributors in parallel
                var techWorldTask = GetDistributorQuote("http://localhost:5101/api/techworld/quote", request);
                var electroComTask = GetDistributorQuote("http://localhost:5102/api/electrocom/quote", request);
                var gadgetCentralTask = GetDistributorQuote("http://localhost:5103/api/gadgetcentral/quote", request);

                await Task.WhenAll(techWorldTask, electroComTask, gadgetCentralTask);

                var techWorldQuote = await techWorldTask;
                var electroComQuote = await electroComTask;
                var gadgetCentralQuote = await gadgetCentralTask;

                // Step 2: Log all quotes received
                Console.WriteLine($"[QUOTATION API] TechWorld: Rs. {techWorldQuote?.TotalPrice ?? 0:N2} (Can fulfill: {techWorldQuote?.CanFulfillCompleteOrder})");
                Console.WriteLine($"[QUOTATION API] ElectroCom: Rs. {electroComQuote?.TotalPrice ?? 0:N2} (Can fulfill: {electroComQuote?.CanFulfillCompleteOrder})");
                Console.WriteLine($"[QUOTATION API] Gadget Central: Rs. {gadgetCentralQuote?.TotalPrice ?? 0:N2} (Can fulfill: {gadgetCentralQuote?.CanFulfillCompleteOrder})");

                // Step 3: Save all quotations to database
                var validQuotes = new List<DistributorQuoteResponse>();
                if (techWorldQuote != null) validQuotes.Add(techWorldQuote);
                if (electroComQuote != null) validQuotes.Add(electroComQuote);
                if (gadgetCentralQuote != null) validQuotes.Add(gadgetCentralQuote);

                if (validQuotes.Count == 0)
                {
                    Console.WriteLine("[QUOTATION API] No valid quotes received from any distributor");
                    return BadRequest(new { Error = "No distributors available" });
                }

                foreach (var quote in validQuotes)
                {
                    _context.Quotations.Add(new Quotation
                    {
                        OrderId = request.OrderId,
                        DistributorName = quote.DistributorName,
                        TotalPrice = quote.TotalPrice,
                        DeliveryDays = quote.DeliveryDays,
                        CanFulfillCompleteOrder = quote.CanFulfillCompleteOrder,
                        QuotationDate = DateTime.UtcNow,
                        Status = "Pending"  // ← ADD THIS LINE
                    });
                }

                await _context.SaveChangesAsync();
                Console.WriteLine($"[QUOTATION API] Saved {validQuotes.Count} quotations to database");

                // Step 4: INTELLIGENT ORDER SPLITTING LOGIC
                var orderSplit = AnalyzeAndSplitOrder(request, validQuotes);

                // Step 5: Save distribution plan to database
                foreach (var distribution in orderSplit.Distributions)
                {
                    _context.OrderDistributions.Add(new OrderDistribution
                    {
                        OrderId = request.OrderId,
                        DistributorName = distribution.DistributorName,
                        ProductId = distribution.ProductId,
                        ProductName = distribution.ProductName,
                        Quantity = distribution.Quantity,
                        UnitPrice = distribution.UnitPrice,
                        TotalPrice = distribution.TotalPrice,
                        Status = "Planned"
                    });
                }

                await _context.SaveChangesAsync();
                Console.WriteLine($"[QUOTATION API] Saved distribution plan with {orderSplit.Distributions.Count} allocations");

                // Step 6: Log the split decision
                Console.WriteLine("[QUOTATION API] ===== ORDER DISTRIBUTION PLAN =====");
                var grouped = orderSplit.Distributions.GroupBy(d => d.DistributorName);
                foreach (var group in grouped)
                {
                    Console.WriteLine($"[QUOTATION API] {group.Key}:");
                    foreach (var item in group)
                    {
                        Console.WriteLine($"[QUOTATION API]   - {item.Quantity}x {item.ProductName} @ Rs. {item.UnitPrice:N2} = Rs. {item.TotalPrice:N2}");
                    }
                }
                Console.WriteLine($"[QUOTATION API] Total Order Value: Rs. {orderSplit.TotalPrice:N2}");
                Console.WriteLine($"[QUOTATION API] Is Split Order: {orderSplit.IsSplitOrder}");
                Console.WriteLine("[QUOTATION API] ===================================");

                // Step 7: Return best option to OrderAPI
                return Ok(new
                {
                    OrderId = request.OrderId,
                    TotalPrice = orderSplit.TotalPrice,
                    IsSplitOrder = orderSplit.IsSplitOrder,
                    Distributions = orderSplit.Distributions,
                    MaxDeliveryDays = orderSplit.MaxDeliveryDays,
                    Message = orderSplit.IsSplitOrder
                        ? $"Order split across {orderSplit.Distributions.GroupBy(d => d.DistributorName).Count()} distributors for best price and availability"
                        : $"Complete order fulfilled by {orderSplit.Distributions.First().DistributorName}"
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[QUOTATION API] Error: {ex.Message}");
                return StatusCode(500, new { Error = "Failed to process quotations", Details = ex.Message });
            }
        }

        /// <summary>
        /// Intelligent algorithm to split order across distributors
        /// Prioritizes: 1) Fulfillment 2) Price 3) Delivery time
        /// </summary>
        private OrderSplitResult AnalyzeAndSplitOrder(QuotationRequestDto request, List<DistributorQuoteResponse> quotes)
        {
            Console.WriteLine("[QUOTATION API] Analyzing order split options...");

            var result = new OrderSplitResult
            {
                Distributions = new List<ProductDistribution>(),
                IsSplitOrder = false
            };

            // Strategy: For each product, choose the distributor with best combination of:
            // 1. Has stock available
            // 2. Lowest price
            // 3. Can fulfill requested quantity

            foreach (var requestedItem in request.Items)
            {
                // Get all available quotes for this product
                var availableQuotes = new List<(string DistributorName, DistributorQuoteResponse.QuotedItem Item, int DeliveryDays)>();

                foreach (var quote in quotes)
                {
                    var quotedItem = quote.Items?.FirstOrDefault(i => i.ProductId == requestedItem.ProductId);
                    if (quotedItem != null && quotedItem.AvailableQuantity > 0)
                    {
                        availableQuotes.Add((quote.DistributorName, quotedItem, quote.DeliveryDays));
                    }
                }

                if (availableQuotes.Count == 0)
                {
                    Console.WriteLine($"[QUOTATION API] WARNING: Product {requestedItem.ProductId} not available from any distributor!");
                    continue;
                }

                // Sort by: 1) Can fulfill full quantity, 2) Price per unit, 3) Delivery time
                var bestOption = availableQuotes
                    .OrderByDescending(q => q.Item.AvailableQuantity >= requestedItem.Quantity) // Full stock first
                    .ThenBy(q => q.Item.UnitPrice) // Then by price
                    .ThenBy(q => q.DeliveryDays) // Then by speed
                    .First();

                // Determine quantity to fulfill
                int quantityToFulfill = Math.Min(requestedItem.Quantity, bestOption.Item.AvailableQuantity);

                result.Distributions.Add(new ProductDistribution
                {
                    DistributorName = bestOption.DistributorName,
                    ProductId = requestedItem.ProductId,
                    ProductName = bestOption.Item.ProductName,
                    Quantity = quantityToFulfill,
                    UnitPrice = bestOption.Item.UnitPrice,
                    TotalPrice = bestOption.Item.UnitPrice * quantityToFulfill,
                    DeliveryDays = bestOption.DeliveryDays
                });

                Console.WriteLine($"[QUOTATION API] Product {requestedItem.ProductId}: Assigned {quantityToFulfill}/{requestedItem.Quantity} units to {bestOption.DistributorName} @ Rs. {bestOption.Item.UnitPrice:N2}/unit");

                // If we couldn't fulfill the full quantity, try to fulfill remaining from other distributors
                int remainingQuantity = requestedItem.Quantity - quantityToFulfill;
                if (remainingQuantity > 0)
                {
                    Console.WriteLine($"[QUOTATION API]   Still need {remainingQuantity} more units...");

                    foreach (var fallbackOption in availableQuotes.Where(q => q.DistributorName != bestOption.DistributorName))
                    {
                        int additionalQty = Math.Min(remainingQuantity, fallbackOption.Item.AvailableQuantity);
                        if (additionalQty > 0)
                        {
                            result.Distributions.Add(new ProductDistribution
                            {
                                DistributorName = fallbackOption.DistributorName,
                                ProductId = requestedItem.ProductId,
                                ProductName = fallbackOption.Item.ProductName,
                                Quantity = additionalQty,
                                UnitPrice = fallbackOption.Item.UnitPrice,
                                TotalPrice = fallbackOption.Item.UnitPrice * additionalQty,
                                DeliveryDays = fallbackOption.DeliveryDays
                            });

                            remainingQuantity -= additionalQty;
                            result.IsSplitOrder = true;
                            Console.WriteLine($"[QUOTATION API]   Assigned additional {additionalQty} units to {fallbackOption.DistributorName} @ Rs. {fallbackOption.Item.UnitPrice:N2}/unit");

                            if (remainingQuantity == 0) break;
                        }
                    }
                }
            }

            // Calculate totals
            result.TotalPrice = result.Distributions.Sum(d => d.TotalPrice);
            result.MaxDeliveryDays = result.Distributions.Any() ? result.Distributions.Max(d => d.DeliveryDays) : 0;

            // Check if order uses multiple distributors
            var uniqueDistributors = result.Distributions.Select(d => d.DistributorName).Distinct().Count();
            if (uniqueDistributors > 1)
            {
                result.IsSplitOrder = true;
            }

            Console.WriteLine($"[QUOTATION API] Order analysis complete: {(result.IsSplitOrder ? "SPLIT" : "SINGLE")} order, Total: Rs. {result.TotalPrice:N2}");

            return result;
        }

        /// <summary>
        /// Helper method to get quote from a distributor
        /// </summary>
        private async Task<DistributorQuoteResponse> GetDistributorQuote(string url, QuotationRequestDto request)
        {
            try
            {
                Console.WriteLine($"[QUOTATION API] Calling: {url}");

                var response = await _httpClient.PostAsJsonAsync(url, new
                {
                    OrderId = request.OrderId,
                    Items = request.Items.Select(i => new { i.ProductId, i.Quantity }).ToList()
                });

                if (response.IsSuccessStatusCode)
                {
                    return await response.Content.ReadFromJsonAsync<DistributorQuoteResponse>();
                }

                Console.WriteLine($"[QUOTATION API] Failed to get quote from {url}: {response.StatusCode}");
                return null;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[QUOTATION API] Error calling {url}: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// Get all quotations for an order
        /// </summary>
        [HttpGet("order/{orderId}")]
        public async Task<IActionResult> GetQuotationsByOrder(int orderId)
        {
            var quotations = await _context.Quotations
                .Where(q => q.OrderId == orderId)
                .OrderBy(q => q.TotalPrice)
                .ToListAsync();

            return Ok(quotations);
        }

        /// <summary>
        /// Get order distribution details
        /// </summary>
        [HttpGet("distribution/{orderId}")]
        public async Task<IActionResult> GetOrderDistribution(int orderId)
        {
            var distributions = await _context.OrderDistributions
                .Where(d => d.OrderId == orderId)
                .ToListAsync();

            return Ok(distributions);
        }
    }

    // DTOs
    public class QuotationRequestDto
    {
        public int OrderId { get; set; }
        public List<QuotationItemDto> Items { get; set; }
    }

    public class QuotationItemDto
    {
        public int ProductId { get; set; }
        public int Quantity { get; set; }
    }

    public class DistributorQuoteResponse
    {
        public string DistributorName { get; set; }
        public decimal TotalPrice { get; set; }
        public int DeliveryDays { get; set; }
        public bool CanFulfillCompleteOrder { get; set; }
        public List<QuotedItem> Items { get; set; }

        public class QuotedItem
        {
            public int ProductId { get; set; }
            public string ProductName { get; set; }
            public int RequestedQuantity { get; set; }
            public int AvailableQuantity { get; set; }
            public decimal UnitPrice { get; set; }
            public decimal TotalPrice { get; set; }
            public bool InStock { get; set; }
        }
    }

    public class OrderSplitResult
    {
        public List<ProductDistribution> Distributions { get; set; }
        public decimal TotalPrice { get; set; }
        public int MaxDeliveryDays { get; set; }
        public bool IsSplitOrder { get; set; }
    }

    public class ProductDistribution
    {
        public string DistributorName { get; set; }
        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal TotalPrice { get; set; }
        public int DeliveryDays { get; set; }
    }
}