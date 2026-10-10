using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;

namespace GadgetHubWeb.Controllers
{
    public class LoginController : Controller
    {
        private readonly HttpClient _httpClient;

        public LoginController(IHttpClientFactory httpClientFactory)
        {
            _httpClient = httpClientFactory.CreateClient();
            _httpClient.BaseAddress = new System.Uri("http://localhost:5001");
        }

        // GET: Show login page
        public IActionResult Index()
        {
            if (HttpContext.Session.GetInt32("CustomerId") != null)
            {
                return RedirectToAction("Create", "Order");
            }
            return View();
        }

        // POST: Process login
        [HttpPost]
        public async Task<IActionResult> Login(string email, string password)
        {
            try
            {
                var loginRequest = new { Email = email, Password = password };
                var response = await _httpClient.PostAsJsonAsync("/api/customers/login", loginRequest);

                if (response.IsSuccessStatusCode)
                {
                    var customer = await response.Content.ReadFromJsonAsync<CustomerInfo>();
                    HttpContext.Session.SetInt32("CustomerId", customer.CustomerId);
                    HttpContext.Session.SetString("CustomerName", customer.CustomerName);
                    HttpContext.Session.SetString("CustomerEmail", customer.Email);
                    return RedirectToAction("Create", "Order");
                }
                else
                {
                    TempData["Error"] = "Invalid email or password. Please try again.";
                    return RedirectToAction("Index");
                }
            }
            catch
            {
                TempData["Error"] = "Unable to connect to server. Please try again later.";
                return RedirectToAction("Index");
            }
        }

        // GET: Show registration page
        public IActionResult Register()
        {
            if (HttpContext.Session.GetInt32("CustomerId") != null)
            {
                return RedirectToAction("Create", "Order");
            }
            return View();
        }

        // POST: Process registration
        [HttpPost]
        public async Task<IActionResult> Register(string customerName, string email, string phone, string password, string confirmPassword)
        {
            try
            {
                if (password != confirmPassword)
                {
                    TempData["Error"] = "Passwords do not match!";
                    return RedirectToAction("Register");
                }

                var registerRequest = new { CustomerName = customerName, Email = email, Phone = phone, Password = password };
                var response = await _httpClient.PostAsJsonAsync("/api/customers/register", registerRequest);

                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadFromJsonAsync<RegisterResponse>();
                    HttpContext.Session.SetInt32("CustomerId", result.CustomerId);
                    HttpContext.Session.SetString("CustomerName", result.CustomerName);
                    HttpContext.Session.SetString("CustomerEmail", result.Email);
                    TempData["Message"] = "Registration successful! Welcome to The Gadget Hub!";
                    return RedirectToAction("Create", "Order");
                }
                else
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    TempData["Error"] = errorContent.Contains("already registered")
                        ? "This email is already registered. Please login instead."
                        : "Registration failed. Please try again.";
                    return RedirectToAction("Register");
                }
            }
            catch
            {
                TempData["Error"] = "Unable to connect to server. Please try again later.";
                return RedirectToAction("Register");
            }
        }

        public IActionResult Logout()
        {
            HttpContext.Session.Clear();
            TempData["Message"] = "You have been logged out successfully.";
            return RedirectToAction("Index");
        }
    }

    public class CustomerInfo
    {
        public int CustomerId { get; set; }
        public string CustomerName { get; set; }
        public string Email { get; set; }
    }

    public class RegisterResponse
    {
        public int CustomerId { get; set; }
        public string CustomerName { get; set; }
        public string Email { get; set; }
        public string Message { get; set; }
    }
}