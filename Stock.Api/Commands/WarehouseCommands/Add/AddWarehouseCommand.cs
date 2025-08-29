using MediatR;
using Stocks.Api.Models;
using Stocks.Api.Services;

namespace Stocks.Api.Commands.WarehouseCommands.Add
{
    public class AddWarehousecommand : IRequest<bool>
    {
        public CreateWarehouseRequest Request { get; set; }
        public AddWarehousecommand(CreateWarehouseRequest request)
        {
            Request = request ;
        }
        public class AddWarehousecommandHandler : IRequestHandler<AddWarehousecommand, bool>
        {
            private readonly WarehouseService _warehouseService;
            public AddWarehousecommandHandler(WarehouseService warehouseService)
            {
                _warehouseService = warehouseService;
            }
            public async Task<bool> Handle(AddWarehousecommand request, CancellationToken cancellationToken)
            {
                return await _warehouseService.Create(request.Request.Name);
            }
        }
    }
}

