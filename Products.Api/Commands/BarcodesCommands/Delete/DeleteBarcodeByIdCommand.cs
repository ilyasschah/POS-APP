using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.BarcodesCommands.Delete
{
    public class DeleteBarcodeByIdCommand : IRequest<bool>
    {
        public int Id { get; }
        public DeleteBarcodeByIdCommand(int id)
        {
            Id = id;
        }
        public class DeleteBarcodeByIdCommandHandler : IRequestHandler<DeleteBarcodeByIdCommand, bool>
        {
            private readonly BarcodeService _barcodeService;
            public DeleteBarcodeByIdCommandHandler(BarcodeService barcodeService)
            {
                _barcodeService = barcodeService;
            }
            public async Task<bool> Handle(DeleteBarcodeByIdCommand request, CancellationToken cancellationToken)
            {
                try
                {
                    return await _barcodeService.Delete(request.Id);
                }
                catch (Exception)
                {
                    throw;
                }
            }
        }
    }
}