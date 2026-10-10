using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using GadgetHubWeb.Models;

namespace GadgetHubWeb.Services
{
    public interface IOrderApiClient
    {
        Task<OrderResponse> CreateOrderAsync(OrderRequest request);
    }

    public class OrderApiClient : IOrderApiClient
    {
        private readonly HttpClient _httpClient;

        public OrderApiClient(HttpClient httpClient)
        {
            _httpClient = httpClient;
            _httpClient.BaseAddress = new System.Uri("http://localhost:5001");
        }

        public async Task<OrderResponse> CreateOrderAsync(OrderRequest request)
        {
            var response = await _httpClient.PostAsJsonAsync("/api/orders", request);
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadFromJsonAsync<OrderResponse>();
        }
    }
}