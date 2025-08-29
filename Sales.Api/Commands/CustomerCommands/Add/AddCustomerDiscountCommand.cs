using MediatR;
using Sales.Api.Models;
using Sales.Api.Services;

namespace Sales.Api.Commands.CustomerCommands.Add
{
    public class AddCustomerDiscountCommand(CreateCustomerDiscountRequest createcustomerdiscountRequest) : IRequest<bool>
    {
        public CreateCustomerDiscountRequest Request { get; set; } = createcustomerdiscountRequest;
        public class AddCustomerDiscountCommandHandler(CustomerDiscountService customerdiscountService) : IRequestHandler<AddCustomerDiscountCommand, bool>
        {
            private readonly CustomerDiscountService _customerdiscountService = customerdiscountService;
            public Task<bool> Handle(AddCustomerDiscountCommand request, CancellationToken cancellationToken)
            {
                return _customerdiscountService.Create(request.Request.CustomerId, request.Request.Type, request.Request.Uid, request.Request.Value);
            }
        }
    }
}
