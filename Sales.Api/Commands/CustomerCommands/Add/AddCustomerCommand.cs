using MediatR;
using Sales.Api.Models;
using Sales.Api.Services;

namespace Sales.Api.Commands.CustomerCommands.Add
{
    public class AddCustomerCommand(CreateCustomerRequest createCustomerRequest) : IRequest<bool>
    {
        public CreateCustomerRequest Request { get; set; } = createCustomerRequest;
        public class AddCustomerCommandHandler(CustomerService customerService) : IRequestHandler<AddCustomerCommand,bool>
        {
            private readonly CustomerService _customerService = customerService;
            public Task<bool> Handle(AddCustomerCommand request, CancellationToken cancellationToken)
            {
                return _customerService.Create(
                    request.Request.Code,
                    request.Request.Name,
                    request.Request.TaxNumber,
                    request.Request.Address,
                    request.Request.PostalCode,
                    request.Request.City,
                    request.Request.CountryId,
                    request.Request.DateCreated,
                    request.Request.DateUpdated,
                    request.Request.Email,
                    request.Request.PhoneNumber,
                    request.Request.IsEnabled,
                    request.Request.IsCustomer,
                    request.Request.IsSupplier,
                    request.Request.DueDatePeriod,
                    request.Request.StreetName,
                    request.Request.AdditionalStreetName,
                    request.Request.BuildingNumber,
                    request.Request.PlotIdentification,
                    request.Request.CitySubdivisionName,
                    request.Request.CountrySubentity,
                    request.Request.IsTaxExempt
                );
            }
        }
    }
}
